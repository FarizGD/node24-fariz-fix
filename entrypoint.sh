#!/bin/bash
set -Eeuo pipefail
cd /home/container
rootfs=/home/container/.proot-debian
export PROOT_TMP_DIR=/home/container/.proot-tmp
mkdir -p "$PROOT_TMP_DIR"
if [[ ! -f "$rootfs/.ready" ]]; then
    if [[ -e "$rootfs" ]]; then
        echo "Incomplete rootfs at $rootfs. Rename it before retrying; no files were deleted." >&2
        exit 1
    fi
    echo "Preparing persistent Debian rootfs. First start may take a few minutes..."
    stage=$(mktemp -d /home/container/.proot-install.XXXXXX)
    trap 'echo "Initialization failed; partial files remain in $stage" >&2' ERR
    tar --no-same-owner --no-same-permissions -xf /opt/debian-rootfs.tar -C "$stage"
    mkdir -p "$stage"/{dev,proc,sys,tmp,run,root,home/container}
    touch "$stage/etc/resolv.conf" "$stage/etc/hosts" "$stage/etc/hostname"
    touch "$stage/.ready"
    mv "$stage" "$rootfs"
    trap - ERR
fi

guest=(proot -0 -r "$rootfs"
    -b /dev -b /proc -b /sys
    -b /etc/resolv.conf -b /etc/hosts -b /etc/hostname
    -b /home/container:/home/container
    -w /home/container)
if ! "${guest[@]}" /bin/true; then
    echo "PRoot could not run. Host ptrace/seccomp restrictions may prevent it; ask the node administrator." >&2
    exit 1
fi
export HOME=/root USER=root LOGNAME=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM="${TERM:-xterm}"
echo "Debian PRoot ready (simulated root, not host root)."
if (( $# )); then
    exec "${guest[@]}" "$@"
elif [[ "${PROOT_USE_STARTUP:-0}" == 1 && -n "${STARTUP:-}" ]]; then
    command_text="${STARTUP//\{\{/\$\{}"
    command_text="${command_text//\}\}/\}}"
    exec "${guest[@]}" /bin/bash -c "$command_text"
else
    # Panel stdin goes directly to Bash; bash.js is no longer needed.
    exec "${guest[@]}" /bin/bash --noprofile --norc -i
fi
