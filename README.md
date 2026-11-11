# LIMA lab server

Gives each member of the LIMA robotics lab their own Ubuntu machine on
`lima-elfes`, with sudo, the GPU, Docker and a remote desktop.

- [Admin guide](docs/ADMIN.md)
- [User guide](docs/USER.md)

| Path | What it is |
|---|---|
| `setup.sh` | Sets up the server: drivers, Incus, network bridge, image, login account |
| `uninstall.sh` | Undoes `setup.sh`, deleting every workspace |
| `preseed.yaml` | Incus setup: storage, network, workspace profile |
| `lima` | Host script: `image`, `add <user>`, and `connect`, which starts a workspace at login |
| `workspace/lima` | User command, installed in every workspace |
| `templates/docker/ros2/` | ROS 2 container template |
| `keys/<user>.pub` | SSH public keys: the record of who has access |
