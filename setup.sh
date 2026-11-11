#!/usr/bin/env bash
# setup.sh -- turns a fresh Ubuntu Server 24.04 into the LIMA server. Safe to run again.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
die() { echo "error: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run it with sudo"
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get full-upgrade -y -qq

# NVIDIA driver. Not --gpgpu: that one has no OpenGL, so no 3D.
apt-get install -y -qq curl gnupg uidmap netcat-openbsd ubuntu-drivers-common
ubuntu-drivers install

# NVIDIA container tools, without which workspaces won't start, and Incus from
# Zabbly, because Ubuntu's archive doesn't have the web UI.
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<'SRC'
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: noble
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/zabbly.asc
SRC
grep -q '^root:1000000:' /etc/subuid || echo root:1000000:1000000000 | tee -a /etc/subuid /etc/subgid >/dev/null
apt-get update -qq
apt-get install -y -qq libnvidia-container-tools incus incus-ui-canonical
[[ -z "${SUDO_USER:-}" ]] || usermod -aG incus-admin "$SUDO_USER"

# Bridge, so workspaces get their own lab addresses. It keeps the interface's MAC,
# so the server keeps its address. The network restarts here.
if ! ip link show br0 >/dev/null 2>&1; then
  dev="$(ip -o route show default | awk '{print $5; exit}')"
  [[ -n "$dev" ]] || die "no default route: is the network up?"
  cat > /etc/netplan/50-cloud-init.yaml <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    $dev:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      interfaces: [$dev]
      macaddress: "$(cat /sys/class/net/"$dev"/address)"
      dhcp4: true
      parameters:
        stp: false
        forward-delay: 0
NETPLAN
  chmod 600 /etc/netplan/50-cloud-init.yaml
  netplan apply    # netplan try refuses bridges
  /usr/lib/systemd/systemd-networkd-wait-online -i br0 -o routable --timeout=60 \
    || die "br0 got no address: check /etc/netplan/50-cloud-init.yaml at the console"
fi

# Answers to <hostname>.local, so laptops on the lab network find the server by name.
apt-get install -y -qq avahi-daemon

# Shared data
mkdir -p /srv/lima/{datasets,bags,models}
chmod 1777 /srv/lima/{datasets,bags,models}
cp -r templates /srv/lima/

# Incus settings and the workspace image
incus admin init --preseed < preseed.yaml
./lima image

# Login account. Its keys only let it run `lima connect`, see `lima add`.
install lima /usr/local/bin/
id lima >/dev/null 2>&1 || useradd -m -G incus-admin lima
install -d -m 700 -o lima -g lima ~lima/.ssh
[[ -f ~lima/.ssh/authorized_keys ]] || install -m 600 -o lima -g lima /dev/null ~lima/.ssh/authorized_keys

echo "Done. Reboot to load the NVIDIA driver."
