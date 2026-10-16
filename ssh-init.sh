#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
if [[ "${1:-}" == "--serve" ]]; then
  exec /usr/sbin/dropbear -R -F -E -p 26006
fi
if [[ ! -x /usr/sbin/dropbear ]]; then
  apt-get update
  apt-get install -y dropbear
fi
mkdir -p /etc/dropbear
if [[ -s /home/container/.ssh-root-password ]]; then
  password=$(head -n 1 /home/container/.ssh-root-password)
  printf 'root:%s\n' "$password" | chpasswd
  unset password
fi
if [[ ! -s /home/container/.ssh-root-password ]] && ! passwd -S root | grep -q '^root P '; then
  echo "[SSH] Root password is locked. Set a private password in /home/container/.ssh-root-password."
fi
echo "[SSH] Dropbear prepared on port 26006; existing root password is preserved."
