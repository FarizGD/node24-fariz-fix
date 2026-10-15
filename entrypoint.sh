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
guest=(proot-distro login node24 --bind /home/container:/home/container --work-dir /home/container)
if ! "${guest[@]}" -- /bin/true; then
    echo "proot-distro could not launch the guest. Check ptrace/seccomp restrictions." >&2
    exit 1
fi
export TERM="${TERM:-xterm}"
echo "Debian proot-distro ready (simulated root, not host root)."
if (( $# )); then
    exec "${guest[@]}" -- "$@"
elif [[ "${PROOT_USE_STARTUP:-0}" == 1 && -n "${STARTUP:-}" ]]; then
    command_text="${STARTUP//\{\{/\$\{}"
    command_text="${command_text//\}\}/\}}"
    exec "${guest[@]}" -- /bin/bash -c "$command_text"
else
    exec "${guest[@]}" -- /bin/bash --noprofile --norc -i
fi
