# Admin guide

Each person gets a container (`user-ws`) on `lima-elfes`, with its own address on
the lab network. They have sudo, the GPU, Docker and a desktop they start when
needed, and no shell on the host.

A workspace only runs while its owner is connected or has a `tmux` session open.
`ssh user-ws` goes through the host's `lima` account, whose only ability is to start
that workspace and connect to it. The workspace powers itself off about a minute
after its last SSH connection closes and its last `tmux` session ends. If someone
forgets a session, `incus stop user-ws` turns it off.

Use the Incus web UI for daily work. `./lima` only builds the image and adds people.

## Setup

On a fresh Ubuntu Server 24.04, from a checkout of this repo. Check the storage pool
in `preseed.yaml` first. The network restarts midway, so use the console or `tmux`.

```bash
sudo ./setup.sh
sudo reboot
```

> `sudo ./setup.sh` takes a while.

It installs the NVIDIA driver, the NVIDIA container tools and Incus with its web
UI. It puts the network interface on a bridge, `br0`, so workspaces get their own
lab addresses, and installs avahi, so the server answers to `lima-elfes.local`. 

It copies the templates to `/srv/lima`. It applies `preseed.yaml`,
builds the workspace image and creates the `lima` login account. Your shells then
start in the repo. Run it again after changing `lima` or the templates.

After the reboot, `nvidia-smi` must work. 

> Reserve the server's address and the VM addresses on the lab router for consistency.
> `lima add` gives users the server's current IP, from `br0`.

## Web UI

Create a tunnel on your machine and leave it open while you access the Web UI:

```bash
ssh -L 8443:localhost:8443 lima@lima-elfes.local
```

> If `lima-elfes.local` doesn't resolve, put the server's IP in that command instead.

Open https://localhost:8443 and accept the self-signed certificate warning. For a first 
use in your browser, follow the instructions on the incus UI.

You may use this for graphs, consoles, snapshots and logs.

## People

**Add.** `user` is any valid Linux username. In workspace names, underscores become
hyphens. The user must send you their ssh public key, and you should place it in this repo's 
`keys/` folder, then commit it.

> Read "Connect" on `USER.md` to learn how to generate the public key.

```bash
# On your laptop
ssh lima@lima-elfes.local mkdir -p LIMA/keys
scp id_ed25519_lima.pub lima@lima-elfes.local:LIMA/keys/user.pub

# On lima-elfes, in the repo
sudo ./lima add user
```

> The "user" username must match in both `keys/user.pub` and the chosen username on `./lima add`.

**Check or repair.** Without a login, it turns itself off again after 30 seconds,
unless you stop its timer. It comes back on the next start.

```bash
incus start user-ws
sleep 5    # let it boot
incus exec user-ws -- systemctl stop lima-idle.timer
incus exec user-ws -- lima check
```

**Restore.** The whole workspace goes back to that snapshot, settings included.
Docker doesn't: its images and containers stay as they are.

```bash
incus snapshot list user-ws
incus snapshot restore user-ws snap3
```

**Remove.** Their files in `/srv/lima` stay.

```bash
incus export user-ws ~/user.tar.gz # Optional copy
incus delete --force user-ws
incus storage volume delete default docker-user
sudo sed -i '/lima connect user"/d' ~lima/.ssh/authorized_keys
```

## Uninstall

```bash
sudo ./uninstall.sh
```

It deletes every workspace, with its snapshots and Docker data, so export any you
want to keep first. It removes Incus, the `lima` login account and the bridge, and
keeps the NVIDIA driver, avahi and the data in `/srv/lima`. If `lima` is also your
own account, it keeps the account and only removes the workspace logins. The network
restarts at the end, so use the console or `tmux`.

## Resources

RAM and CPU are shared, with no cap: anyone can use whatever is free, and 8 GiB is
only the fair share the user guide asks for. If RAM runs out, the kernel kills
processes, usually the largest, whoever owns them, and host services aren't exempt.
A busy CPU just slows everyone down. Disk has no quotas, and nothing manages GPU
memory.

> Never set `limits.memory.enforce=soft`: despite its description, a workspace that passes the limit freezes.

```bash
incus config set user-ws limits.memory=16GiB
incus config set user-ws limits.cpu=8
incus list -c ns4m
```

## Troubleshooting

- **`The NVIDIA container tools couldn't be found`:** install `libnvidia-container-tools` on the host.
- **`lima check` says no hardware 3D:** if `ldconfig -p | grep libEGL_nvidia` prints nothing on the host, run `ubuntu-drivers install` and reboot. Otherwise check `nvidia.driver.capabilities` includes `graphics`.
- **`lima check` says Docker's volume is not attached:** add it with `incus config device add user-ws docker disk pool=default source=docker-user path=/var/lib/docker`.
- **`lima check` says slow Docker storage:** the storage pool's filesystem doesn't support overlay. Use ext4 or XFS.
- **No GPU in a workspace after a driver upgrade:** restart the workspace, then reboot the host if that fails.
- **User wasn't created:** `incus exec user-ws -- cloud-init status --long`.
- **`ssh user-ws` prints `SSH-2.0-OpenSSH…: command not found`:** their key also opens a plain shell on the `lima` account, as happens when it's your admin key and you log in to the server as `lima`. Give the workspace a different key: remove it and add it again.
- **Can't SSH:** `Permission denied` means the wrong key, so compare `keys/user.pub` with `~lima/.ssh/authorized_keys`. For anything else, try `incus start user-ws` and read the error. 

## Security and backups

- Never set `security.privileged`: root in a workspace would be root on the host.
- Keep the Incus API on localhost: it controls the whole machine.
- The `lima` account can control Incus, and only `restrict,command=` holds it back. Add keys with `lima add`, and never give it a password.
- A running workspace's SSH is reachable from anywhere the lab network is.
- Snapshots sit on the same disk, so they aren't backups: run `incus export` on a schedule for those. Each one is a full copy of the workspace, without Docker's data, so watch the free space. A running workspace freezes during the copy, which is why they run at 4 a.m. server time.
