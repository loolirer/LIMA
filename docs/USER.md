# User guide

You have your own Ubuntu 24.04 machine on the lab server, with sudo, the GPU and
Docker. Nobody else can see it, so install whatever you want.

## Connect

Send the admin your public key, from `cat ~/.ssh/id_ed25519.pub` (create one with
`ssh-keygen -t ed25519` if needed). They'll send you a block for `~/.ssh/config` on
your laptop:

```
Host user-ws
    User                  user
    ProxyCommand          ssh -T -o StrictHostKeyChecking=accept-new lima@lima-elfes
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

```bash
lima desktop              # or: lima desktop 2560x1440
lima desktop stop         # when you're done, because it holds memory
```

With `ssh` connected, point a VNC client (Remmina, TigerVNC or RealVNC) at
`localhost:5901`.

Start 3D apps with `vglrun` so they use the GPU, like `vglrun rviz2` or
`vglrun gz sim` in the ROS container below.

## ROS 2

ROS runs in a container you build from the lab's template:

```bash
cp -r /srv/lima/templates/docker ~/ros2
cd ~/ros2
mkdir -p ros2_ws/src
docker compose run --build --rm dev    # a few minutes the first time
```

This opens a shell with ROS ready, where you run `colcon build --symlink-install`.
Your source is in `~/ros2/ros2_ws`, so you can edit it from outside the container.
GUI apps appear on your desktop, so start that first.

Your topics mix with everyone else's on the lab network, robots included. To keep
them apart, pick a number from 1 to 101 and set `ROS_DOMAIN_ID` in
`docker-compose.yml`. Your robot needs the same number.

To change the setup, edit `Dockerfile` (the ROS version is in `FROM`) and run the
same command again.

For your own containers, add `--gpus all` to use the GPU.

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
- **`ssh` exits without a word right after a logout:** your machine was shutting down.
  Run it again.
- **A job or window is gone:** your machine turns off after you log out. Run long
  jobs in `tmux`.
- **VNC won't connect:** keep `ssh` open and check the desktop is on with `lima`.
- **3D is slow:** start the app with `vglrun`.
- **A process died with `Killed`:** the machine probably ran out of memory, maybe
  not because of you. For builds, try `colcon build --parallel-workers 4`.
- **`lima check` shows an X:** send the output to the admin.
