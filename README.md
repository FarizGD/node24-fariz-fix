# Node 24 + persistent Debian PRoot for Pterodactyl

Image: `ghcr.io/farizgd/node24-fariz-fix:latest`

After the GitHub Actions build and package smoke test pass, select this image in the panel (not termux/termux-docker) and stop/start the server so Wings pulls it.

The default console is an interactive Bash shell. The egg's STARTUP command is ignored by default, so no bash.js is needed. Set PROOT_USE_STARTUP=1 if you want the existing egg STARTUP command to run inside Debian instead. Docker arguments explicitly supplied to the image run inside Debian.

On first start the bundled Debian/Node filesystem is extracted to /home/container/.proot-debian. This may take several minutes and requires space for the unpacked OS and development tools. Installed packages persist in that directory across restarts and image replacement. Existing server files are not removed.

Try:
```sh
whoami
node -v
apt update
apt install -y fastfetch
fastfetch
```

Root is simulated by PRoot. The actual container user remains unprivileged, and no-new-privileges remains enabled. No host root, Docker daemon or normal systemd support is provided. Package scripts requiring real kernel privileges may not work. PRoot adds syscall overhead.

The host must permit PRoot's ptrace operations. If the preflight fails, the node administrator must inspect the runtime restrictions; this image cannot override them.

The image supports amd64 and arm64. CI tests package installation and persistence on native amd64 with an arbitrary UID, read-only outer filesystem, all capabilities dropped and no-new-privileges, before publishing. This does not prove compatibility with every Wings host.

A later image upgrade does not overwrite your persistent guest. For a fresh guest, stop the server and rename .proot-debian to a backup name using the file manager before starting again. Keep a backup of anything important inside it. Interrupted first-start extraction is retained in .proot-install.* for inspection; remove only confirmed unused partial directories while the server is stopped.
