# User guide

You have your own Ubuntu 24.04 machine on the lab server, with sudo, the GPU and
Docker. Nobody else can see it, so install whatever you want.

## Connect

Create a key just for LIMA, then send the admin the line the second command prints:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_lima
```

The admin sends back a command that adds your machine to `~/.ssh/config`. Paste all
of it into a terminal on your laptop. It looks like this:

```bash
mkdir -p ~/.ssh && chmod 600 ~/.ssh/config
```

```
Host user-ws
    User                  user
    IdentityFile          ~/.ssh/id_ed25519_lima
    IdentitiesOnly        yes
    ProxyCommand          ssh -T -i ~/.ssh/id_ed25519_lima -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new lima@lima-elfes.local
    StrictHostKeyChecking accept-new
    LocalForward          5901 localhost:5901
    LogLevel              FATAL
```

Then run `ssh user-ws`. Inside, `lima` shows your status and `lima check` tests the
GPU, 3D and Docker.

**Logging in turns your machine on, and logging out turns it off.** It starts in a
few seconds and stops about a minute after your last logout, ending everything
running on it, including the desktop. Your files stay. It stays on for as long as
you're connected, even if idle.

**To keep a job running after you log out, run it in `tmux`.** The machine stays on
while a `tmux` session is open. Run `tmux`, start the job, then detach with
`Ctrl-b d` or just close the connection. To check on it, log in and run
`tmux attach`. When you're done, `exit` the session, or the machine stays on.

## Desktop

An XFCE desktop, over VNC:

```bash
lima desktop
lima desktop stop # When you're done, because it holds memory
```

With `ssh` connected, point a VNC client (Remmina, TigerVNC or RealVNC) at
`localhost:5901`.

Start 3D apps with `vglrun` so they use the GPU, like `vglrun rviz2`.

## ROS 2

The lab's ROS 2 template is a `docker/` folder for your project's repo:

```bash
cp -r /srv/lima/templates/docker/ros2 ~/my_project/docker
cd ~/my_project/docker
docker compose up -d --build
docker exec -it dev bash
```

Inside, your repo is in `/root/ros2_ws/src`. Add `docker/.bash_history` to your
project's `.gitignore`.

## Files

| Path | Use | Snapshots |
|---|---|---|
| `~` | Code, builds, anything private | Daily, kept 2 weeks |
| `/srv/lima/datasets`, `bags`, `models` | Shared with the lab | None |

Everyone can read `/srv/lima`, but only you can change or delete your files there.

Snapshots protect you from mistakes, not a dead disk, so push your code to git. If
you delete something important, stop working and ask the admin straight away.

Snapshots run at 4 a.m. and copy all of `~`. If your machine is on, it pauses during
the copy and then carries on, so keep big data in `/srv/lima`.

## Sharing the machine

- **Memory:** 8 GiB is your fair share, and you can go past it while memory is free.
  If it runs out, the largest process is killed, whoever owns it. Your job can die
  because of someone else's, so close what you aren't using and warn the lab before
  big runs.
- **CPU:** you can use every idle core. When it's busy, everyone slows down.
- **GPU:** check `nvidia-smi` before big jobs. Nothing manages GPU memory, so if you
  take it all, other people's jobs fail.
- **Disk:** delete failed runs and run `docker image prune` now and then.

## Problems

- **Can't SSH:** check you're on the lab network or VPN. `Permission denied` means
  the admin has the wrong key. For anything else, ask the admin.
- **`Could not resolve hostname lima-elfes.local`:** you're probably not on the lab
  network itself, for example on the VPN. In `~/.ssh/config`, replace
  `lima-elfes.local` with the server's IP.
- **`ssh` exits without a word right after a logout:** your machine was shutting down.
  Run it again.
- **A job or window is gone:** your machine turns off after you log out. Run long
  jobs in `tmux`.
- **VNC won't connect:** keep `ssh` open and check the desktop is on with `lima`.
- **3D is slow:** start the app with `vglrun`.
- **A process died with `Killed`:** the machine probably ran out of memory, maybe
  not because of you. For builds, try `colcon build --parallel-workers 4`.
- **`lima check` shows an X:** send the output to the admin.
