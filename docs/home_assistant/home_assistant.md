# Home Assistant

```bash
kubectl create namespace home-assistant
kubectl apply -f home_assistant.yaml
```

If `configmap` is updated then update the deployment

```bash
kubectl rollout restart deployment home-assistant -n home-assistant
kubectl rollout status  deployment home-assistant -n home-assistant
```

If this hangs we can force it by scaling down to 0 and back up again

```bash
kubectl -n home-assistant scale deploy/home-assistant --replicas=0
kubectl -n home-assistant get pods

kubectl -n home-assistant delete rs -l app=home-assistant

kubectl -n home-assistant scale deploy/home-assistant --replicas=1
kubectl -n home-assistant rollout status deploy/home-assistant
```

TODO. implement with kustomize

```yaml
spec:
  template:
    metadata:
      annotations:
        # Update this value when the ConfigMap changes.
        configmap.home-assistant.checksum: "{{ .Values or kustomize var with sha256 of the ConfigMap }}"
```

## Troubleshooting

Check the status of the certificate in the `traefik` namespace:

```bash
kubectl get certificates -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificates {} -n home-assistant

kubectl get certificaterequests -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe certificaterequests {} -n home-assistant

kubectl get order -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe order {} -n home-assistant

kubectl get challenges -n home-assistant --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl describe challenges {} -n home-assistant
```

```bash
kubectl exec -n home-assistant -it deploy/home-assistant -- sh
```

## Matter Server

```bash
kubectl apply -f matter_server.yaml
```

```bash
kubectl logs -f deployment/matter-server -n home-assistant
```

Look for these entries in the log:

```text
INFO [matter_server.server.server] Starting the Matter Server...
INFO [matter_server.server.helpers.paa_certificates] Fetching the latest PAA root certificates...
INFO [matter_server.server.server] Matter Server successfully initialized.
```

Just like with Home Assistant updates may get stuck on old replicas.

```bash
kubectl -n home-assistant scale deploy/matter-server --replicas=0
kubectl -n home-assistant get pods

kubectl -n home-assistant delete rs -l app=matter-server

kubectl -n home-assistant scale deploy/matter-server --replicas=1
kubectl -n home-assistant rollout status deploy/matter-server
```

### Testing Matter Server Connectivity

```bash
kubectl get pod -n home-assistant -l app=matter-server -o jsonpath='{.items[0].status.hostIP}'
tcping -f 4 -t 5 192.168.1.12 5580
```

## OTBR Server

Using OTBR in SMHJUB Nano MG24.

## HACS

Because the Home Assistant container is ephemeral, HACS must be injected into the persistent volume (`/config`) via an `initContainer`. This ensures HACS persists across pod restarts and image updates.

Verify File Existence

```bash
kubectl exec -it <pod-name> -n home-assistant -- ls -l /config/custom_components/hacs/manifest.json
```

Verify Integration Loader. Check the logs for the specific "Custom Integration" warning, which confirms Home Assistant has detected the files:

```bash
kubectl logs -l app=home-assistant -n home-assistant --tail=100 | grep "hacs"
```

Cache Clearing (Maintenance). If HACS is present in the files but missing from the UI "Add Integration" search, the internal component cache must be wiped to force a re-scan:

```bash
kubectl exec -it <pod-name> -n home-assistant -- rm -rf /config/.storage/custom_components
```

**Note:** Always ensure **Advanced Mode** is enabled in your Home Assistant User Profile before attempting to add HACS.

Once the pod restarts and the logs confirm detection, the integration is activated via the UI. If the search bar is unresponsive due to browser caching, the setup flow is forced via direct URL:

`[http://<NODE_IP>:8123](https://home-assistant.local.spaelling.xyz/)/config/integrations/dashboard/add?domain=hacs`

### VS COde Server

The VS Code Server is deployed as a separate pod within the `home-assistant` namespace. It provides a web-based IDE accessible via `https://code.home-assistant.local.spaelling.xyz`. This allows for direct editing of Home Assistant configuration files without needing to access the pod's shell.

```bash
kubectl create secret generic vscode-password --namespace=home-assistant --from-literal=code-server-password='your_actual_password_here'
```

```bash
kubectl apply -f code-server.yaml
```

### Nordpool, Energi Data Service & ApexCharts

Once HACS is installed, the Nordpool, Energi Data Service, and ApexCharts integrations can be added via the UI.

#### Heatpump Automation

Create the Helpers
Go to Settings > Devices & Services > Helpers and create the following:

Type,Name,Entity ID (Suggested),Purpose
Dropdown,Heatpump Strategy,input_select.heatpump_strategy,"Stores current mode (Boost, Normal, Reduce, Off)"
Number,Heatpump Base Temperature,input_number.heatpump_base_temperature,Your slider for the standard target
Number,Heatpump Boost Value,input_number.heatpump_boost_value,"Slider for the ""5 degree"" adjustment"

The Economic AutomationThis logic uses your Base Temperature as the pivot. It calculates the targets dynamically: $Target = Base \pm Delta$.

Script:

```yaml
heatpump_control.yaml
```

Automation (create as automation)

```yaml
heatpump_control_steering.yaml
```

Use [code.home-assistant.local.spaelling.xyz](https://code.home-assistant.local.spaelling.xyz/?folder=/config) to place `heatpump_control.py` inside `/config/python_scripts/`.

Create a secret to hold the credentials for the Warmlink API and the device code for the heatpump.

```bash
kubectl create secret generic heatpump-warmlink-credentials --from-literal=HEATPUMP_USER='PLACEHOLDER' --from-literal=HEATPUMP_PASS='PLACEHOLDER' --from-literal=HEATPUMP_DEVICE_CODE='PLACEHOLDER' -n home-assistant
```

Can verify these are loaded as environment variables in the Home Assistant pod:

```bash
kubectl exec -it $(kubectl get pods -n home-assistant -l app=home-assistant -o jsonpath='{.items[0].metadata.name}') -n home-assistant -- env | grep HP_
```
