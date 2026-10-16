#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [[ "${1:-}" == "--serve" ]]; then
  exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
fi
# Install the UCF-free package into existing persistent guests if they are not configured.
# Newly provisioned guests already contain it from the build image.
if ! dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -qx 'install ok installed' || [[ ! -x /usr/sbin/sshd ]]; then
  echo "[SSH] Repairing OpenSSH with patched local Debian package..."
  dpkg -i /tmp/openssh-server-proot.deb
fi
apt-mark hold openssh-server >/dev/null 2>&1 || true
# Some imported PRoot filesystems are missing sshd despite a configured dpkg status.
# The Docker build includes a binary from the *same* Debian guest image.
if [[ ! -x /usr/sbin/sshd ]]; then
  echo "[SSH] Binary missing after package installation, checking locations..."
  ls -l /usr/sbin/sshd /usr/bin/sshd /tmp/sshd-bundled 2>&1 || true
  if [[ -x /usr/bin/sshd ]]; then
    mkdir -p /usr/sbin
    ln -sf /usr/bin/sshd /usr/sbin/sshd
  elif [[ -r /tmp/sshd-bundled ]]; then
    mkdir -p /usr/sbin
    cp /tmp/sshd-bundled /usr/sbin/sshd
    chmod 755 /usr/sbin/sshd
  fi
fi
if [[ ! -x /usr/sbin/sshd ]]; then
  echo "[SSH] sshd still missing after recovery" >&2
  ls -ld /usr /usr/sbin /usr/bin || true
  exit 1
fi
mkdir -p /etc/ssh /run/sshd
chmod 755 /run/sshd
getent group sshd >/dev/null || groupadd --system sshd
id sshd >/dev/null 2>&1 || useradd --system --no-create-home --home-dir /run/sshd --shell /usr/sbin/nologin --gid sshd sshd
ssh-keygen -A
password_file=/home/container/.ssh-root-password
if [[ -s "$password_file" ]]; then
  password=$(head -n 1 "$password_file")
  printf 'root:%s\n' "$password" | chpasswd
  unset password
else
  echo "[SSH] Set root password once using a local .ssh-root-password file; no password embedded in public repo."
fi
cat > /etc/ssh/sshd_config <<'CONFIG'
Port 26006
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication no
AuthenticationMethods password
UsePAM no
PermitEmptyPasswords no
PidFile /tmp/sshd.pid
Subsystem sftp internal-sftp
CONFIG
/usr/sbin/sshd -t
echo "[SSH] SSH configuration ready on port 26006"
