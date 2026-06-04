#Requires -Version 7.0
<#
.SYNOPSIS
  Commission one or more Matter-over-Thread devices onto the homelab Thread mesh,
  phone-free, via the in-cluster Matter Server and rpi01's onboard Bluetooth.

.DESCRIPTION
  The PowerShell equivalent of commission-thread-devices.sh. It drives the Matter
  Server's WebSocket API (the same path Home Assistant uses): it reads the
  preferred Thread dataset that HA holds, sets it on the controller, then runs
  commission_with_code for each device over BLE.

  You supply each device's PAIRING CODE (the 11-digit manual code printed on the
  device, e.g. 3062-912-8403; dashes/spaces are ignored). The pairing code is
  REQUIRED — it carries the setup passcode for the secure handshake. A device that
  is merely in pairing mode and nearby is NOT auto-onboarded. The Matter Server
  assigns the node_id itself.

.PREREQUISITES
  - PowerShell 7+
  - kubectl on PATH, configured against the homelab cluster
      (e.g. $env:KUBECONFIG = '/path/to/kubeconfig', or pass -Kubeconfig)
  - You must be ON the home LAN or a VPN into it — the API server is the LAN
    address 192.168.1.11:6443 and is unreachable from outside.
  - matter-server + home-assistant deployments running in the home-assistant ns.
  - PHYSICAL: each device next to rpi01 and in pairing mode at its turn (the Pi's
    onboard Bluetooth is short-range). This cannot be done remotely.

.EXAMPLE
  ./Invoke-MatterCommission.ps1 -Code 3062-912-8403

.EXAMPLE
  ./Invoke-MatterCommission.ps1 -Code 30629128403,11223345566 -Kubeconfig ~/.kube/homelab

.EXAMPLE
  ./Invoke-MatterCommission.ps1 -CodeFile ./codes.txt -NoPrompt
#>

function Invoke-MatterCommission {
    [CmdletBinding(DefaultParameterSetName = 'Codes')]
    param(
        # One or more pairing codes. Dashes/spaces are stripped.
        [Parameter(Mandatory, ParameterSetName = 'Codes', Position = 0)]
        [string[]]$Code,

        # A file with one pairing code per line (# starts a comment).
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [string]$CodeFile,

        # Commission back-to-back without pausing between devices.
        [switch]$NoPrompt,

        [string]$Namespace = 'home-assistant',

        # Optional path to a kubeconfig; sets $env:KUBECONFIG for this run.
        [string]$Kubeconfig
    )

    # --- gather and normalise pairing codes -------------------------------
    $codes = if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path -LiteralPath $CodeFile)) {
            throw "Code file not found: $CodeFile"
        }
        Get-Content -LiteralPath $CodeFile |
            ForEach-Object { ($_ -split '#', 2)[0] } |
            ForEach-Object { $_ -replace '[\s-]', '' } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }
    else {
        $Code | ForEach-Object { $_ -replace '[\s-]', '' } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    if ($null -eq $codes -or $codes.Count -eq 0) {
        throw 'No usable pairing codes were provided.'
    }
    foreach ($c in $codes) {
        if ($c -notmatch '^\d+$') {
            throw "Pairing code '$c' is not all digits after stripping dashes/spaces."
        }
    }
    Write-Verbose ("Collected {0} pairing code(s)." -f $codes.Count)

    # --- prerequisite checks ----------------------------------------------
    if ($Kubeconfig) {
        if (-not (Test-Path -LiteralPath $Kubeconfig)) {
            throw "Kubeconfig not found: $Kubeconfig"
        }
        $env:KUBECONFIG = (Resolve-Path -LiteralPath $Kubeconfig).Path
        Write-Verbose "Using KUBECONFIG=$env:KUBECONFIG"
    }
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw 'kubectl is not on PATH. Install it and configure access to the homelab cluster.'
    }

    Write-Verbose "Checking cluster reachability (namespace '$Namespace')..."
    & kubectl get deployment matter-server --namespace $Namespace --request-timeout=15s --output name *> $null
    if ($LASTEXITCODE -ne 0) {
        throw @"
Cannot reach the matter-server deployment in namespace '$Namespace'.
The cluster API is the LAN address 192.168.1.11:6443 — you must be on the home
network or a VPN into it. (If you are away from home, commissioning cannot run
anyway: each device has to be physically next to rpi01 in pairing mode.)
"@
    }

    # --- fetch the preferred Thread dataset (TLV hex) HA holds ------------
    $datasetPy = @'
import json
d = json.load(open("/config/.storage/thread.datasets"))["data"]
print(next(x["tlv"] for x in d["datasets"] if x["id"] == d["preferred_dataset"]))
'@

    Write-Verbose 'Fetching preferred Thread dataset from Home Assistant...'
    try {
        $tlvRaw = $datasetPy | & kubectl exec -i --namespace $Namespace deploy/home-assistant `
            -c home-assistant -- python3 -
        if ($LASTEXITCODE -ne 0) { throw "kubectl exec returned exit code $LASTEXITCODE." }
    }
    catch {
        throw "Failed to read the Thread dataset from Home Assistant: $_"
    }
    $tlv = ($tlvRaw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1).Trim()
    if ([string]::IsNullOrWhiteSpace($tlv)) {
        throw 'Home Assistant returned no preferred Thread dataset. Is the smhub border router set up and preferred in HA?'
    }
    Write-Verbose ("Got Thread dataset ({0} hex chars)." -f $tlv.Length)
    Write-Debug   "Thread dataset TLV: $tlv"

    # --- per-device commissioning -----------------------------------------
    # This Python runs inside the matter-server pod: it sets the Thread dataset
    # on the controller, then commissions the single code from $env:CODE over BLE.
    # Exit codes: 0 OK, 2 set_thread_dataset failed, 3 commission failed, 4 error.
    $commissionPy = @'
import asyncio, json, os, sys, aiohttp

async def cmd(ws, mid, command, **args):
    await ws.send_str(json.dumps({"message_id": mid, "command": command, "args": args}))
    while True:
        m = json.loads(await ws.receive_str())
        if m.get("message_id") == mid:
            return m

async def main():
    async with aiohttp.ClientSession() as s, \
               s.ws_connect("ws://localhost:5580/ws", heartbeat=30) as ws:
        await ws.receive_str()  # server_info banner
        r = await cmd(ws, "ds", "set_thread_dataset", dataset=os.environ["TLV"])
        if r.get("error_code"):
            print("set_thread_dataset FAILED:", r.get("details", r)); sys.exit(2)
        r = await cmd(ws, "co", "commission_with_code",
                      code=os.environ["CODE"], network_only=False)
        if r.get("error_code"):
            print("commission FAILED:", r.get("error_code"), r.get("details", "")); sys.exit(3)
        res = r.get("result") or {}
        print("OK node_id=" + str(res.get("node_id", res)))
        sys.exit(0)

try:
    asyncio.run(main())
except Exception as e:
    print("ERROR:", e); sys.exit(4)
'@

    $ok = 0; $fail = 0; $skipped = 0; $n = 0
    $total = $codes.Count
    foreach ($c in $codes) {
        $n++
        Write-Host ""
        Write-Host ("==> Device {0}/{1}  (pairing code: {2})" -f $n, $total, $c) -ForegroundColor Cyan

        if (-not $NoPrompt) {
            Write-Host '    Put THIS device in pairing mode and place it next to rpi01.'
            # if/continue/break target the foreach loop directly; a switch would
            # capture them and the loop control would not work as intended.
            $ans = (Read-Host '    Ready? [Enter to commission, s to skip, q to quit]').Trim().ToLower()
            if ($ans -eq 's') { Write-Host '    skipped.'; $skipped++; continue }
            if ($ans -eq 'q') { Write-Host '    quitting.'; break }
        }

        Write-Verbose "Commissioning code $c ..."
        # TLV/CODE are passed into the pod via kubectl's `env` command, so no
        # local environment variables are needed here.
        $out = $commissionPy | & kubectl exec -i --namespace $Namespace deploy/matter-server `
            -- env "TLV=$tlv" "CODE=$c" python3 - 2>&1
        $code_exit = $LASTEXITCODE

        $out | ForEach-Object { Write-Host "    $_" }
        if ($code_exit -eq 0) {
            $ok++
        }
        else {
            $fail++
            Write-Host "    (BLE 'CHIP Error 0x32 Timeout' / 'Discovery timed out' means the device" -ForegroundColor Yellow
            Write-Host "     was not in pairing mode or out of rpi01 BLE range. Re-trigger pairing," -ForegroundColor Yellow
            Write-Host "     move it closer, and retry.)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host ("==> Done. {0} succeeded, {1} failed, {2} skipped." -f $ok, $fail, $skipped) -ForegroundColor Green
    if ($fail -gt 0) { exit 1 }
}

Invoke-MatterCommission @args
