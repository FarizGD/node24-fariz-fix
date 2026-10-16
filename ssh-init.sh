#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [[ "${1:-}" == "--serve" ]]; then
  exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
fi
if [[ ! -x /usr/sbin/sshd ]]; then
  echo "[SSH] Installing openssh-server..."
  apt-get update
  apt-get install -y --reinstall openssh-server
fi
if [[ ! -x /usr/sbin/sshd ]]; then echo "[SSH] openssh-server unavailable" >&2; exit 1; fi
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
