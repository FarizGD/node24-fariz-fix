#!/bin/bash
set -Eeuo pipefail
cd /home/container
export PROOT_TMP_DIR=/home/container/.proot-tmp
export TMPDIR="$PROOT_TMP_DIR"
mkdir -p "$PROOT_TMP_DIR"
# PRoot-Distro manages its own persistent container layout in HOME.
# The previous .proot-debian guest is deliberately never removed or overwritten.
if ! proot-distro list --quiet 2>/dev/null | grep -Fxq node24; then
    echo "Installing bundled Debian/Node guest with proot-distro..."
    proot-distro install /opt/debian-rootfs.tar --name node24
fi
# Custom OpenSSH is installed through its patched Debian package, not binary copying.
guest=(proot-distro login node24 --bind /home/container:/home/container --bind "$PROOT_TMP_DIR:/tmp" --bind /opt/ssh-init.sh:/usr/local/sbin/ssh-init.sh --bind /opt/openssh-server-proot.deb:/tmp/openssh-server-proot.deb --work-dir /home/container)
if ! "${guest[@]}" -- /bin/bash -ec 'test -d /tmp && touch /tmp/.proot-write-test && rm /tmp/.proot-write-test'; then
    echo "proot-distro could not launch the guest. Check ptrace/seccomp restrictions." >&2
    exit 1
fi
export TERM="${TERM:-xterm}"
echo "Debian proot-distro ready (simulated root, not host root)."
# Finish SSH package installation and configuration before giving the console to APT users.
# This prevents concurrent dpkg/apt transactions during CI and interactive startup.
if ! "${guest[@]}" -- /bin/bash /usr/local/sbin/ssh-init.sh --prepare > /home/container/ssh.log 2>&1; then
    echo "[SSH] Preparation failed, check /home/container/ssh.log" >&2
    tail -n 20 /home/container/ssh.log >&2 || true
    exit 1
fi
# Serve SSH in the background after configuration is complete.
"${guest[@]}" -- /bin/bash /usr/local/sbin/ssh-init.sh --serve >> /home/container/ssh.log 2>&1 &
ssh_pid=$!
sleep 2
if ! kill -0 "$ssh_pid" 2>/dev/null; then
    echo "[SSH] Startup exited, check /home/container/ssh.log" >&2
    tail -n 20 /home/container/ssh.log >&2 || true
else
    echo "[SSH] Initializer started (PID $ssh_pid); log: /home/container/ssh.log"
fi
if (( $# )); then
    exec "${guest[@]}" -- "$@"
elif [[ "${PROOT_USE_STARTUP:-0}" == 1 && -n "${STARTUP:-}" ]]; then
    command_text="${STARTUP//\{\{/\$\{}"
    command_text="${command_text//\}\}/\}}"
    exec "${guest[@]}" -- /bin/bash -c "$command_text"
else
    exec "${guest[@]}" -- /bin/bash --noprofile --norc -i
fi
