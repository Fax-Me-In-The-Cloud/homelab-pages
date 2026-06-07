# Home Assistant

[Home Assistant](https://www.home-assistant.io/) is the home automation platform. It runs in the `home-assistant` namespace alongside the Matter Server and a VS Code Server for config editing. (The Thread Border Router runs externally on the SMHUB Nano MG24, not in the cluster.)

## Deploy

```bash
kubectl create namespace home-assistant
kubectl apply -f home_assistant.yaml
```

## Update after ConfigMap changes

Home Assistant does not watch its ConfigMap for changes. After editing any ConfigMap, trigger a rollout:

```bash
kubectl rollout restart deployment home-assistant -n home-assistant
kubectl rollout status deployment home-assistant -n home-assistant
```

If the rollout hangs (old pods not terminating), force it by scaling to zero and back:

```bash
kubectl -n home-assistant scale deploy/home-assistant --replicas=0
kubectl -n home-assistant get pods
kubectl -n home-assistant delete rs -l app=home-assistant
kubectl -n home-assistant scale deploy/home-assistant --replicas=1
kubectl -n home-assistant rollout status deploy/home-assistant
```

## Troubleshooting

Inspect certificate issuance — Home Assistant uses a cert-manager certificate like all other services:

```bash
kubectl get certificates -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificates {} -n home-assistant

kubectl get certificaterequests -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificaterequests {} -n home-assistant

kubectl get order -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe order {} -n home-assistant

kubectl get challenges -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe challenges {} -n home-assistant
```

Open a shell inside the pod:

```bash
kubectl exec -n home-assistant -it deploy/home-assistant -- sh
```

## HACS

HACS (Home Assistant Community Store) must be installed via an `initContainer` because the Home Assistant container is ephemeral — anything written to the container filesystem outside of `/config` is lost on restart. The `initContainer` copies HACS into the persistent volume at `/config/custom_components/hacs/` before the main container starts.

### Verify HACS is present

```bash
kubectl exec -it <pod-name> -n home-assistant -- ls -l /config/custom_components/hacs/manifest.json
```

### Verify Home Assistant detected HACS

```bash
kubectl logs -l app=home-assistant -n home-assistant --tail=100 | grep "hacs"
```

### Clear the component cache (if HACS is present but missing from the UI)

```bash
kubectl exec -it -n home-assistant "$(kubectl get pod -n home-assistant -l app=home-assistant -o jsonpath='{.items[0].metadata.name}')" -- rm -rf /config/.storage/custom_components
```

Restart the pod after clearing the cache. **Enable Advanced Mode** in your Home Assistant User Profile before searching for HACS in the integrations list.

If the search bar is unresponsive, force the setup flow directly:

```
https://home-assistant.local.spaelling.xyz/config/integrations/dashboard/add?domain=hacs
```

## VS Code Server

The VS Code Server pod provides a browser-based IDE for editing Home Assistant configuration files directly in the `/config` persistent volume.

Create the password secret:

```bash
kubectl create secret generic vscode-password --namespace=home-assistant --from-literal=code-server-password='your_actual_password_here'
```

Deploy:

```bash
kubectl apply -f code-server.yaml
```

The editor is available at `https://code.home-assistant.local.spaelling.xyz`.

## Matter Server

The Matter Server enables Home Assistant to communicate with Matter-compatible smart home devices.

```bash
kubectl apply -f matter_server.yaml
```

> **Persistence — `--storage-path /data` is required.** The container args
> override the image's default command, so `--storage-path /data` must be
> passed explicitly. Without it the server writes its controller database
> (`chip.json`, holding the fabric and all commissioned nodes) to
> `/root/.matter_server/` on the ephemeral container filesystem instead of
> the PVC, and **loses every onboarded device on each restart**. Confirm it
> is persisting to the volume:
>
> ```bash
> kubectl exec -n home-assistant deploy/matter-server -- ls -l /data/chip.json
> ```

> **Service connectivity.** Home Assistant connects to the Matter Server over
> a websocket. The `matter-server-service` (ClusterIP) selects pods by
> `app: matter-server` — keep `externalTrafficPolicy` out of the `selector`
> block or the Service ends up with no endpoints. The Matter integration in
> HA can then use `ws://matter-server-service.home-assistant:5580/ws`; the
> deployment is also pinned to `rpi01` via nodeAffinity, so the node IP
> (`ws://192.168.1.11:5580/ws`) is a stable fallback.

Check the logs to confirm it started successfully:

```bash
kubectl logs -f deployment/matter-server -n home-assistant
```

Look for these lines:

```text
INFO [matter_server.server.server] Starting the Matter Server...
INFO [matter_server.server.helpers.paa_certificates] Fetching the latest PAA root certificates...
INFO [matter_server.server.server] Matter Server successfully initialized.
```

If the rollout gets stuck, apply the same scale-to-zero approach used for Home Assistant:

```bash
kubectl -n home-assistant scale deploy/matter-server --replicas=0
kubectl -n home-assistant delete rs -l app=matter-server
kubectl -n home-assistant scale deploy/matter-server --replicas=1
kubectl -n home-assistant rollout status deploy/matter-server
```

### Verify Matter Server connectivity

Get the node IP the pod is running on and test the Matter port:

```bash
HOST_IP="$(kubectl get pod -n home-assistant -l app=matter-server -o jsonpath='{.items[0].status.hostIP}')"
echo "Matter Server is on node $HOST_IP"
tcping -f 4 -t 5 "$HOST_IP" 5580
```

Using the retrieved `hostIP` keeps the test correct even when the pod
schedules on a different node.

### Commissioning Matter-over-Thread devices

This is the gotcha for this homelab. Most current IKEA devices (e.g.
**TIMMERFLOTTE** temperature/humidity sensor) are **Matter-over-Thread**, not
Zigbee. Commissioning a factory-reset Matter-over-Thread device needs two
things at pairing time:

1. **A Bluetooth (BLE) handshake** with the device while it advertises in
   pairing mode, and
2. handing the device the **Thread operational dataset** so it can join the
   mesh.

**The phone path is a dead end here.** With a self-built OTBR (the smhub Nano
MG24) and an iPhone, iOS refuses Thread commissioning because Apple only
accepts an Apple-ecosystem border router (HomePod/Apple TV); the "Thread
Border Router required" popup comes from iOS itself, before the request ever
reaches Home Assistant. Android would work, but is not available here.

**Phone-free commissioning via the cluster's own Bluetooth.** The Raspberry
Pi nodes have an onboard Bluetooth controller, and `bluetoothd` runs on the
host. By mounting the host D-Bus system bus into the Matter Server pod and
passing `--bluetooth-adapter 0`, the in-cluster Matter Server does the BLE
handshake itself — no phone in the loop. See the `--bluetooth-adapter` flag
and the `/run/dbus` `hostPath` mount in `matter_server.yaml`. The CHIP SDK's
native BLE stack talks to BlueZ on `rpi01` (where the deployment is pinned via
nodeAffinity).

**Workflow:**

1. Confirm the smhub border router and a usable dataset exist in HA:
   **Settings → Devices & Services → Thread** — the smhub should be listed,
   marked **preferred**, with credentials.
2. Make sure the Matter Server has BLE enabled (above) and is running on
   `rpi01`.
3. Put the device into pairing mode (e.g. factory-reset an IKEA TIMMERFLOTTE so
   its LED blinks rapidly) and place it **physically near `rpi01`** — the onboard
   Pi Bluetooth is low-power, so keep it within a few metres / same room.
4. Commission the device programmatically. The HA UI's *Add Matter device* flow
   insists on the phone companion app, but driving the Matter Server directly
   works headless: use the commissioning scripts (`commission-thread-devices.sh`
   or `Invoke-MatterCommission.ps1`) or the WebSocket API below, passing the
   11-digit pairing code (e.g. `3062-912-8403`). The Matter Server scans over
   BLE, performs PASE, hands over the Thread dataset, and the device joins the
   smhub mesh.

> **Range and timing are the usual failure.** A `commission_with_code` that
> ends in `BLEManagerImpl.cpp: CHIP Error 0x32: Timeout` followed by
> `Discovery timed out` means the BLE *adapter worked* but no device
> advertisement was heard in the ~20 s scan window — i.e. the device was not
> in pairing mode, its window had closed, or it was out of range of `rpi01`.
> Re-trigger pairing mode, move the device next to `rpi01`, and retry. (The
> parallel `Wi-Fi PAF` / `Long discriminator is required` error in the same
> log is an unrelated discovery transport and can be ignored.)
>
> **Future:** HA's network-Bluetooth-proxy commissioning (server-side
> groundwork in HA 2026.06 / Matter Server 8.5) will let any HA Bluetooth
> proxy on the LAN provide the BLE leg, relaxing the "near `rpi01`"
> constraint.

#### Manual commissioning via the Matter Server WebSocket API

When the HA UI flow is flaky, you can drive the Matter Server directly over
its WebSocket API (`ws://<matter-server>:5580/ws`) — this is exactly what HA
does under the hood, and it gives you the raw CHIP error if something fails.
For a Thread device you must set the Thread dataset on the controller **first**,
then commission. The command names are the API command strings (e.g.
`set_thread_dataset`, `commission_with_code`), not the Python method names.

```bash
# 1. Grab the active Thread dataset TLV (hex) HA holds for the smhub network:
kubectl exec -n home-assistant deploy/home-assistant -c home-assistant -- python3 -c 'import json;d=json.load(open("/config/.storage/thread.datasets"))["data"]; print(next(x["tlv"] for x in d["datasets"] if x["id"]==d["preferred_dataset"]))'

# 2. From inside the matter-server pod, set the dataset then commission the code.
#    network_only=false lets it commission a brand-new (BLE) device.
kubectl exec -i -n home-assistant deploy/matter-server -- env TLV="<tlv-hex>" python3 - <<'PY'
import asyncio, json, os, aiohttp
async def main():
    async with aiohttp.ClientSession() as s, s.ws_connect("ws://localhost:5580/ws", heartbeat=30) as ws:
        await ws.receive_str()                       # server_info banner
        async def cmd(mid, command, **args):
            await ws.send_str(json.dumps({"message_id": mid, "command": command, "args": args}))
            while True:
                m = json.loads(await ws.receive_str())
                if m.get("message_id") == mid:
                    return m
        print("set_thread_dataset:", await cmd("d", "set_thread_dataset", dataset=os.environ["TLV"]))
        print("commission:", await cmd("c", "commission_with_code",
                                       code="3062-912-8403", network_only=False))
asyncio.run(main())
PY
```

A successful run returns a node id (e.g. `node_id: 2, available: True`); HA then
auto-creates the entities (`sensor.<device>_temperature`, `…_humidity`,
`…_battery`, etc.). Because the Matter Server persists to the PVC
(`--storage-path /data`), the node survives pod restarts. Confirm a live read
with `get_node`, or inspect nodes with the `get_nodes` command.

### Bluetooth ownership — Matter Server only, not Home Assistant

`rpi01` has exactly **one** Bluetooth controller (`hci0`), and both Home
Assistant and the Matter Server are pinned to `rpi01`. The Matter Server owns
that adapter for commissioning, so Home Assistant's own Bluetooth integration
must **not** also try to claim it — an HA Bluetooth proxy here would be
pointless (same node, same radio) and the two would contend.

Home Assistant has no D-Bus mount, so its auto-discovered Bluetooth adapter
entries can never connect and spew `habluetooth.scanner … 'NoneType' object
has no attribute 'send'` every ~30 s. **Disable those entries:** in
**Settings → Devices & Services → Bluetooth**, disable each
`Raspberry Pi (Trading) Ltd …` adapter (they will not be re-enabled by
discovery once disabled). The errors stop immediately and Matter is
unaffected.

## OTBR (OpenThread Border Router)

OTBR bridges Thread devices (e.g. Matter over Thread) to the IP network.

> **The Thread Border Router runs on the SMHUB Nano MG24** at **`192.168.1.168`**,
> exposing the OpenThread REST API on port **8081**. Home Assistant's *OpenThread
> Border Router* integration points at `http://192.168.1.168:8081`.
>
> Verify the border router is healthy (should return JSON with
> `"State": "leader"` and the network name):
>
> ```bash
> curl -s http://192.168.1.168:8081/node
> curl -s http://192.168.1.168:8081/node/dataset/active
> ```
>
> In Home Assistant, **Settings → Devices & Services → Thread** should list
> this border router and show a preferred dataset whose border-agent ID and
> extended address match the `BaId` / `ExtAddress` returned by `/node`.

## Energy management — Nordpool & Heatpump automation

### Install HACS integrations

After HACS is set up, install via the HACS UI:

- **Nordpool** — electricity spot price sensor
- **Energi Data Service** — Danish grid tariff data
- **ApexCharts Card** — custom Lovelace chart card

### Heatpump automation

The heatpump control logic adjusts the target temperature based on electricity spot prices. It uses three Helpers defined in **Settings → Devices & Services → Helpers**:

| Type | Name | Entity ID | Purpose |
|---|---|---|---|
| Dropdown | Heatpump Strategy | `input_select.heatpump_strategy` | Current mode (Boost / Normal / Reduce / Off) |
| Number | Heatpump Base Temperature | `input_number.heatpump_base_temperature` | Standard target temperature |
| Number | Heatpump Boost Value | `input_number.heatpump_boost_value` | Delta applied in Boost/Reduce mode |

The target temperature is calculated as `Base ± Delta` depending on the selected strategy.

Place the Python script in the persistent volume using [VS Code Server](#vs-code-server):

```
https://code.home-assistant.local.spaelling.xyz/?folder=/config
```

Copy `heatpump_control.py` to `/config/python_scripts/`.

Apply the script and automation manifests (create as automation in the UI or via YAML):

```yaml
heatpump_control.yaml       # the script
heatpump_control_steering.yaml  # the automation that triggers it
```

Create the secret with Warmlink API credentials for the heatpump:

```bash
kubectl create secret generic heatpump-warmlink-credentials --from-literal=HEATPUMP_USER='PLACEHOLDER' --from-literal=HEATPUMP_PASS='PLACEHOLDER' --from-literal=HEATPUMP_DEVICE_CODE='PLACEHOLDER' -n home-assistant
```

Verify the credentials are loaded as environment variables in the Home Assistant pod:

```bash
kubectl exec -it $(kubectl get pods -n home-assistant -l app=home-assistant -o jsonpath='{.items[0].metadata.name}') -n home-assistant -- env | grep HEATPUMP_
```

## Adaptive lighting (summer-aware)

Dynamically adjusts smart-light brightness and colour temperature by time of
day and season, and reduces brightness automatically during the long Danish
summer evenings. Two layers:

1. **Sun-elevation circadian control** via the
   [Adaptive Lighting](https://github.com/basnijholt/adaptive-lighting) HACS
   integration — cooler/brighter near midday, warmer/dimmer toward sunset.
2. **Cloud-cover boost** — a companion automation that raises `max_brightness`
   on overcast/wet days (using `weather.forecast_home`) and lowers it when
   clear, on top of the circadian curve.

Config: `adaptive_lighting/adaptive_lighting.yaml` (a Home Assistant package
containing both the `adaptive_lighting:` switches and the boost automation).

### High-latitude summer tuning

At ~56°N the sun rises around 04:00 and sets around 22:00 in midsummer, which
naively keeps lights bright all evening and ramps them up at dawn. The package
clamps the virtual sun events with time bounds:

| Setting | Value | Effect |
|---|---|---|
| `min_sunrise_time` | `06:00` | Summer: do **not** ramp up at a 04:00 sunrise. |
| `max_sunrise_time` | `08:00` | Winter: reach full "morning" by 08:00. |
| `min_sunset_time` | `20:00` | Winter: do **not** start dimming before 20:00. |
| `max_sunset_time` | `21:30` | **Summer key:** begin the evening wind-down by 21:30 even though the sun is still up. |

`max_sunset_time` is the single most important lever for the summer-evening
goal. Johan's room winds down earlier (`20:30`).

### Apply

1. Install **Adaptive Lighting** via HACS, then restart Home Assistant.
2. Enable packages in `configuration.yaml`:

    ```yaml
    homeassistant:
      packages: !include_dir_named packages
    ```

3. Copy `adaptive_lighting.yaml` to `/config/packages/` (use the VS Code
   Server) and restart Home Assistant. Two switches appear:
   `switch.adaptive_lighting_living_areas` and `switch.adaptive_lighting_johan`.

### Notes & gotchas

- **Manual override:** `take_over_control` stops adapting a light once you
  change it by hand; `autoreset_control_seconds: 3600` resumes after an hour.
  (The integration option is `autoreset_control_seconds`, not the
  `manual_control_reset_time` name seen in some older write-ups.)
- **Warm-white bulbs** (Johan) only have their brightness adapted; colour
  temperature stays in the cosy 2200–2700 K range.
- **IKEA bulbs** can mishandle simultaneous colour-temp + brightness commands —
  `separate_turn_on_commands` + `send_split_delay: 500` split them.
- **Zigbee mesh:** short `transition: 1` keeps frequent updates light on the
  mesh; raise `interval` if lights feel laggy.
- **Unassigned bulbs:** `light.ikea_of_sweden_tradfri_bulb_e27_ws_globe_1055lm_4`
  and `light.kajplats_e27_ws_globe_1521lm` have no area and are **not** included
  yet — assign them an area and add them to the `lights:` list to cover them.
- **Optional lux refinement:** a real illuminance sensor
  (`sensor.night_light_illuminance`) could drive brightness via
  [adaptive-lux-lighting](https://github.com/max-mathieu/adaptive-lux-lighting)
  instead of the weather-condition heuristic, for more accurate cloud
  compensation.

### Utility scripts

Helper scripts for factory-resetting IKEA bulbs by power-cycling the
smart plug they are connected to. Each takes a `switch` entity as input and
toggles it on a fixed schedule — the bulb resets after the required number of
off/on cycles.

```yaml
reset_ikea_bulb.yaml       # 6 power cycles (standard TRADFRI bulb)
reset_ikea_kajplats.yaml   # 12 power cycles (KAJPLATS bulb)
```

These live in Home Assistant as scripts (**Settings → Automations & Scenes →
Scripts**). Paste the YAML into a new script in YAML-edit mode, or add the
contents under the matching key in `/config/scripts.yaml`.
