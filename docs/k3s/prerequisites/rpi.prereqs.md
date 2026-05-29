# Raspberry Pi

To run K3s on a Raspberry Pi, we need to ensure that the system is properly configured. Below are the steps to prepare Raspberry Pi for K3s installation.

On the Raspberry Pi modify `/boot/firmware/cmdline.txt` to include `cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory`

```bash
nano /boot/firmware/cmdline.txt
```

Paste in `cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory` (make sure it is all on one line)

After a rebot verify with

```bash
# Show the *effective* kernel cmdline after boot
cat /proc/cmdline
```

edit `/etc/dphys-swapfile` and set `CONF_SWAPSIZE=0`

```bash
nano /etc/dphys-swapfile
```

then run the following commands to disable and reconfigure swap

```bash
apt update
apt install dphys-swapfile -y
apt remove systemd-zram-generator -y
dphys-swapfile swapoff
dphys-swapfile setup
```

## Static IP address

A static IP address is recommended for the Raspberry Pi to ensure consistent connectivity.

```bash
nano /etc/hosts
```

and change 127.0.0.1 to desired static IP address

This should return the static IP address

```bash
hostname --ip-address
```

Next use `nmcli` to set a static IP address.

```bash
nmcli connection add type ethernet ifname eth0 con-name static-eth0 ipv4.addresses 192.168.1.11/24 ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.60 ipv4.method manual
nmcli connection up static-eth0
```

use `ip a` to verify the static IP address is set correctly

## Fans

Set the fans to only turn on when the CPU temperature exceeds 60 degrees Celsius.

```bash
sudo nano /boot/firmware/config.txt
```

Add this line to the end of the file:

```text
# Enable cooling fan control
dtoverlay=gpio-fan,gpiopin=14,temp=70000
```

We can check the temperature of the CPU with the following command:

```bash
watch -n 1 vcgencmd measure_temp
```

We can check the fan speed using `cat /sys/class/thermal/cooling_device0/cur_state` which should be a value between 0 and 255 (does seem binary, 1 is 100%, 0 is off). Or checking `GPIO 14` using `pinctrl get 14` where `hi` means the fan is on (100% speed) and `lo` means the fan is off (0% speed).

```bash
cat /sys/class/thermal/cooling_device0/cur_state
pinctrl get 14
```
