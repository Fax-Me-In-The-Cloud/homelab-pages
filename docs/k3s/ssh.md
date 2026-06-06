# SSH

SSH key-based authentication is required for k3sup to install and manage k3s nodes without interactive password prompts.

## Generate an SSH key pair

If you do not already have a key pair, generate one. The `-C` flag adds a comment to identify the key:

```bash
ssh-keygen -t rsa -b 4096 -C "homelab"
```

This creates `~/.ssh/id_rsa` (private key) and `~/.ssh/id_rsa.pub` (public key). Keep the private key secure and never share it.

## Copy the public key to each node

Run this for every node that k3sup will manage. Replace the IP with each node's static address:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@192.168.1.11
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@192.168.1.12
```

This appends your public key to `~/.ssh/authorized_keys` on the remote host, allowing passwordless login.

## Verify the connection

Test that key-based auth works before proceeding to the k3s installation:

```bash
ssh -i ~/.ssh/id_rsa pi@192.168.1.11
```

If the connection succeeds without prompting for a password, the node is ready for k3sup.

## Passwordless sudo

k3sup runs commands on the remote nodes with `--sudo true`, which requires passwordless sudo for the `pi` user. Verify this is configured on each node:

```bash
sudo visudo
```

The `pi` user (or the `sudo` group) should have a line like:

```text
%sudo   ALL=(ALL:ALL) NOPASSWD: ALL
```
