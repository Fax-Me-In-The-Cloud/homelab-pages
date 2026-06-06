# Housekeeping

Basic housekeeping tasks to perform on each node before installing k3s. These apply after the [Raspberry Pi prerequisites](prerequisites/rpi.prereqs.md) are complete.

## Change passwords

The default `pi` user password must be changed before the node is connected to the network. Also change the root password:

```bash
passwd
passwd root
```

## System update

Bring the system fully up to date before installing anything:

```bash
sudo apt update && sudo apt upgrade -y
```

Reboot after the upgrade if the kernel was updated:

```bash
sudo reboot
```

## Install useful tools

A few tools are useful throughout the setup process:

```bash
sudo apt install -y curl jq nano
```

- `curl` — used for downloading manifests and testing endpoints
- `jq` — used to parse JSON output (e.g. when fetching kube-vip release versions)
- `nano` — for editing config files on the node

## Set the hostname

Give each node a meaningful hostname that matches its role. This makes it easier to identify nodes in `kubectl get nodes` output:

```bash
sudo hostnamectl set-hostname rpi-1
```

Repeat on each node with an appropriate name (`rpi-1`, `rpi-2`, etc.).

Update `/etc/hosts` on each node to include all other nodes:

```bash
sudo nano /etc/hosts
```

Add entries such as:

```text
192.168.1.11  rpi-1
192.168.1.12  rpi-2
```

## Verify time sync

k3s is sensitive to clock drift between nodes. Confirm NTP is running:

```bash
timedatectl status
```

`System clock synchronized: yes` and `NTP service: active` should both be present.
