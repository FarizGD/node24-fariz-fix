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
guest=(proot-distro login node24 --bind /home/container:/home/container --bind "$PROOT_TMP_DIR:/tmp" --bind /opt/ssh-init.sh:/usr/local/sbin/ssh-init.sh --work-dir /home/container)
if ! "${guest[@]}" -- /bin/bash -ec 'test -d /tmp && touch /tmp/.proot-write-test && rm /tmp/.proot-write-test'; then
    echo "proot-distro could not launch the guest. Check ptrace/seccomp restrictions." >&2
    exit 1
fi
export TERM="${TERM:-xterm}"
echo "Debian proot-distro ready (simulated root, not host root)."
# Start SSH within a separate guest session so the interactive console remains available.
"${guest[@]}" -- /bin/bash /usr/local/sbin/ssh-init.sh > /home/container/ssh.log 2>&1 &
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
