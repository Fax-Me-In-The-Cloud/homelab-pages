#!/usr/bin/env bash
#
# commission-thread-devices.sh
# -----------------------------
# Commission one or more Matter-over-Thread devices onto the homelab Thread
# mesh via the in-cluster Matter Server, phone-free, using rpi01's onboard
# Bluetooth. This is the scripted version of the manual WebSocket flow in
# home_assistant.md ("Manual commissioning via the Matter Server WebSocket API").
#
# You provide PAIRING CODES (the 11-digit manual code on the device, e.g.
# 3062-912-8403, dashes optional). The Matter Server assigns the node_id itself.
#
# Usage:
#   ./commission-thread-devices.sh 30629128403 11223345566
#   ./commission-thread-devices.sh -f codes.txt        # one code per line, # comments ok
#   ./commission-thread-devices.sh -y 30629128403      # don't pause between devices
#
# Requirements:
#   - kubectl configured against the homelab cluster (KUBECONFIG)
#   - matter-server + home-assistant deployments running in the home-assistant ns
#   - Each device physically next to rpi01 and in pairing mode at its turn.
#
# Note: the Thread dataset (which embeds the network key) is passed to the pod
# via `env TLV=...`, so it is briefly visible in the local process list (ps).
# This is accepted for a single-user homelab admin box; do not run on a shared host.
#
set -euo pipefail

NS=home-assistant
PROMPT=1
CODES=()

usage() {
  echo "Usage: $0 [-y] <pairing-code> [pairing-code...]" >&2
  echo "       $0 [-y] -f <codes-file>   (one code per line, # for comments)" >&2
  exit 1
}

# --- parse args ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--no-prompt) PROMPT=0; shift ;;
    -f|--file)
      [[ -f "${2:-}" ]] || { echo "file not found: ${2:-}" >&2; exit 1; }
      while IFS= read -r line; do
        line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]-')"
        [[ -n "$line" ]] && CODES+=("$line")
      done < "$2"
      shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) CODES+=("$(echo "$1" | tr -d '[:space:]-')"); shift ;;
  esac
done
[[ ${#CODES[@]} -gt 0 ]] || usage

# --- fetch the preferred Thread dataset (TLV hex) that HA holds ------------
echo "==> Fetching preferred Thread dataset from Home Assistant..."
TLV="$(kubectl exec -n "$NS" deploy/home-assistant -c home-assistant -- \
  python3 -c 'import json;d=json.load(open("/config/.storage/thread.datasets"))["data"];print(next(x["tlv"] for x in d["datasets"] if x["id"]==d["preferred_dataset"]))')"
[[ -n "$TLV" ]] || { echo "ERROR: could not read a preferred Thread dataset from HA." >&2; exit 1; }
echo "    got dataset (${#TLV} hex chars)."

# --- commission each code, one device at a time ---------------------------
ok=0; fail=0; n=0; total=${#CODES[@]}
for code in "${CODES[@]}"; do
  n=$((n+1))
  echo
  echo "==> Device ${n}/${total}  (pairing code: ${code})"
  if [[ "$PROMPT" -eq 1 ]]; then
    echo "    Factory-reset / put THIS device in pairing mode and place it next to rpi01."
    read -r -p "    Ready? [Enter to commission, s to skip, q to quit] " ans
    case "$ans" in
      s|S) echo "    skipped."; continue ;;
      q|Q) echo "    quitting."; break ;;
    esac
  fi

  # Run a self-contained commission inside the matter-server pod: set the
  # Thread dataset on the controller, then commission_with_code over BLE.
  if kubectl exec -i -n "$NS" deploy/matter-server -- \
       env TLV="$TLV" CODE="$code" python3 - <<'PY'
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
            print("    set_thread_dataset FAILED:", r.get("details", r)); sys.exit(2)
        r = await cmd(ws, "co", "commission_with_code",
                      code=os.environ["CODE"], network_only=False)
        if r.get("error_code"):
            print("    commission FAILED:", r.get("error_code"), r.get("details", "")); sys.exit(3)
        res = r.get("result") or {}
        node = res.get("node_id", res)
        print(f"    OK  node_id={node}")
        sys.exit(0)

try:
    asyncio.run(main())
except Exception as e:
    print("    ERROR:", e); sys.exit(4)
PY
  then
    ok=$((ok+1))
  else
    fail=$((fail+1))
    echo "    (BLE 'CHIP Error 0x32 Timeout' / 'Discovery timed out' = device not in"
    echo "     pairing mode or out of rpi01 BLE range. Re-trigger pairing, move closer, retry.)"
  fi
done

echo
echo "==> Done. ${ok} succeeded, ${fail} failed, $((total-ok-fail)) skipped."
[[ "$fail" -eq 0 ]]
