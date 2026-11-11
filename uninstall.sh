#!/usr/bin/env bash
# uninstall.sh -- undoes setup.sh. Keeps the NVIDIA driver, avahi and /srv/lima's data.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
die() { echo "error: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run it with sudo"
export DEBIAN_FRONTEND=noninteractive

read -rp "This deletes every workspace, with its snapshots and Docker data. Type yes: " answer
[[ "$answer" == yes ]] || die "nothing done"
exec </dev/null    # without a terminal, incus commands wait for YAML on stdin

# Workspaces, images and volumes. The storage pool can only go once nothing uses it.
if command -v incus >/dev/null; then
  for ct in $(incus list -f csv -c n); do incus delete --force "$ct"; done
  for img in $(incus image list -f csv -c f); do incus image delete "$img"; done
  for vol in $(incus storage volume list default -f csv -c tn 2>/dev/null | awk -F, '$1 == "custom" {print $2}'); do
    incus storage volume delete default "$vol"
  done
  incus profile delete lima-ws 2>/dev/null || true
  incus profile device remove default root 2>/dev/null || true
  incus storage delete default 2>/dev/null || true
fi

# Incus and the NVIDIA container tools, with their package sources
apt-get purge -y -qq $(dpkg-query -W -f '${Package}\n' 'incus*' 'libnvidia-container*' 2>/dev/null)
apt-get autoremove --purge -y -qq
rm -f /etc/apt/sources.list.d/zabbly-incus-stable.sources /etc/apt/keyrings/zabbly.asc \
  /etc/apt/sources.list.d/nvidia-container-toolkit.list /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
rm -rf /var/lib/incus /var/log/incus /var/cache/incus
sed -i '/^root:1000000:1000000000$/d' /etc/subuid /etc/subgid
groupdel incus-admin 2>/dev/null || true
groupdel incus 2>/dev/null || true

# Login account. If it's also a person's account, like yours, only the workspace
# logins go.
rm -f /usr/local/bin/lima
rm -rf /srv/lima/templates
if id lima >/dev/null 2>&1; then
  if [[ "${SUDO_USER:-}" == lima ]] || id -nG lima | grep -qw sudo; then
    sed -i '/command="\/usr\/local\/bin\/lima connect /d' ~lima/.ssh/authorized_keys
  else
    userdel -r lima 2>/dev/null || true
  fi
fi

# Your shells no longer start in this repo.
[[ -z "${SUDO_USER:-}" ]] || sudo -H -u "$SUDO_USER" bash -c \
  'rest="$(grep -vxF "cd $1" ~/.bashrc)" && printf "%s\n" "$rest" > ~/.bashrc' _ "$(printf %q "$PWD")" || true

# Bridge: the network interface gets its address directly again. The network
# restarts here.
if [[ -d /sys/class/net/br0/brif ]]; then
  dev=""
  for port in /sys/class/net/br0/brif/*; do
    port="${port##*/}"
    [[ -e "/sys/class/net/$port/device" ]] && dev="$port"
  done
  [[ -n "$dev" ]] || die "no network interface on br0"
  cat > /etc/netplan/50-cloud-init.yaml <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    $dev:
      dhcp4: true
NETPLAN
  chmod 600 /etc/netplan/50-cloud-init.yaml
  ip link delete br0
  netplan apply
  /usr/lib/systemd/systemd-networkd-wait-online -i "$dev" -o routable --timeout=60 \
    || die "$dev got no address: check /etc/netplan/50-cloud-init.yaml at the console"
fi

echo "Done."
