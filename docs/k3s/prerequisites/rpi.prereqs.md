# Raspberry Pi Prerequisites

These steps prepare a fresh Raspberry Pi for k3s. They must be completed on each node before running the k3s installer.

All commands run as root on the Pi unless noted otherwise. Connect via serial console or a temporary DHCP address initially.

## Enable cgroups

k3s requires cgroup support for CPU and memory isolation. On Raspberry Pi OS, cgroups are not enabled by default and must be added to the kernel command line.

Edit the boot command line:

```bash
nano /boot/firmware/cmdline.txt
```

Append the following to the end of the single line — do not add a newline:

```text
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

Reboot, then verify the parameters were applied:

```bash
cat /proc/cmdline
```

You should see `cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory` in the output.

## Disable swap

k3s (and Kubernetes in general) requires swap to be disabled. Swap can cause unpredictable memory pressure behaviour in containerised workloads.

Edit the swap configuration:

```bash
nano /etc/dphys-swapfile
```

Set `CONF_SWAPSIZE=0`, then apply and disable:

```bash
apt update
apt install dphys-swapfile -y
apt remove systemd-zram-generator -y
dphys-swapfile swapoff
dphys-swapfile setup
```

## Set a static IP address

A static IP is required so that k3sup can reliably connect to each node and so the cluster has stable addresses.

Edit `/etc/hosts` so the hostname resolves to the static IP. Keep the
`127.0.0.1 localhost` line untouched — changing it breaks localhost
resolution. Instead, point the `127.0.1.1 <hostname>` line at the static IP
(or add a `<static-ip> <hostname>` line):

```bash
sudo nano /etc/hosts
```

For example, on node 1:

```text
127.0.0.1       localhost
192.168.1.11    node1
```

Verify the hostname resolves to the expected address:

```bash
hostname --ip-address
```

Configure the static IP using `nmcli`. Adjust `ipv4.addresses`, `ipv4.gateway`, and `ipv4.dns` to match your network:

```bash
nmcli connection add type ethernet ifname eth0 con-name static-eth0 ipv4.addresses 192.168.1.11/24 ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.60 ipv4.method manual
nmcli connection up static-eth0
```

Confirm with:

```bash
ip a
```

## Configure fan control

The Raspberry Pi 5 active cooler fan can be noisy at low loads. Configure it to only spin when the CPU temperature exceeds a threshold.

```bash
sudo nano /boot/firmware/config.txt
```

Add the following at the end of the file. `gpiopin=14` is the default for the official Raspberry Pi active cooler. `temp=70000` means 70 °C (value is in millidegrees):

```text
dtoverlay=gpio-fan,gpiopin=14,temp=70000
```

Reboot for the overlay to take effect.

### Checking temperature and fan state

Monitor CPU temperature in real time:

```bash
watch -n 1 vcgencmd measure_temp
```

Check whether the fan is currently running:

```bash
pinctrl get 14
```

`hi` means the fan is on (100% speed). `lo` means the fan is off.

Alternatively, read the cooling device state directly (0 = off, 255 = full speed):

```bash
cat /sys/class/thermal/cooling_device0/cur_state
```
