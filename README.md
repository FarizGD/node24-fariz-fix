# Node 24 + Debian via PRoot-Distro for Pterodactyl

Image: `ghcr.io/farizgd/node24-fariz-fix:latest`

This image uses the upstream **Termux PRoot-Distro** Python CLI on a regular Debian host, not Termux and not a handwritten `proot -r` invocation. The Docker container still runs as an unprivileged user. It does not grant real root or kernel capabilities.

On first start, the image imports its prebuilt Debian Trixie + Node.js 24 tarball using `proot-distro install ... --name node24`. It then starts the guest with `proot-distro login node24`. The installation and future `apt` changes persist under the `container` user's home directory, which Pterodactyl mounts at `/home/container`.

**Important migration note:** Existing `/home/container/.proot-debian` from the old image is **left untouched**. PRoot-Distro has a different container layout, so this creates a fresh guest. Back up files in the old rootfs and copy any required files/configuration into the new guest manually. The Pterodactyl home directory is bind-mounted and remains accessible inside the guest. Do not delete `.proot-debian` until you have migrated what you need.

The default console opens interactive Bash. The egg's STARTUP is ignored by default. Set `PROOT_USE_STARTUP=1` to execute the egg STARTUP within Debian. Explicit Docker command arguments also execute within Debian.

After CI publishes a new image, select `ghcr.io/farizgd/node24-fariz-fix:latest` in your panel and restart the container so Wings pulls it.

Try inside the console:
```sh
whoami
node -v
apt update
apt install -y fastfetch
fastfetch
```

PRoot-Distro CLI is on the **outer Docker host environment**, not installed inside the nested guest. The host has the CLI in `/opt/proot-distro-venv/bin/proot-distro`. Use the panel's normal startup to enter the guest. This is still rootless: package post-install scripts that demand real kernel capabilities or privileged mounts may fail, including some OpenSSH configurations.

The node must allow PRoot ptrace operations. The image supports amd64/arm64 depending on the CI build. Existing GitHub Actions build/test workflow should be reviewed for old `.proot-debian` assumptions and updated before relying on green CI.

## Automatic SSH (password login)

The image starts OpenSSH inside the persistent `node24` guest on TCP port `26006` on every Pterodactyl startup, separately from the interactive panel console. The server's allocation must expose TCP/26006. SSH root password login is enabled and public-key authentication is disabled.

Set the root password **once** inside the panel console without editing the egg or nest:

```sh
read -r -s -p 'SSH root password: ' pw; echo; printf '%s\\n' "$pw" > /home/container/.ssh-root-password; unset pw; chmod 600 /home/container/.ssh-root-password
```

Restart the Pterodactyl server. Check `/home/container/ssh.log` if SSH does not start. The file `.ssh-root-password` is local persistent state: never commit it or post it publicly. Change the password immediately if it has been exposed. The password is reapplied at startup, so edit that file when rotating it.

A public root account with password-only SSH is high risk; prefer keys in production. PRoot is not real root and some SSH sessions may still fail due to host limitations.
