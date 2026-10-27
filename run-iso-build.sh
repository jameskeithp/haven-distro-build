#!/bin/bash
# HAVEN ISO build runner - execute on the build host (Ubuntu 24.04, 50GB+ disk).
# Usage: ./run-iso-build.sh   (runs detached via nohup; watch ~/iso-build.log)
set -e
cd "$(dirname "$0")/live-build"

echo "=== Fixing executable bits (not always preserved by git push) ==="
chmod +x config/hooks/live/*.hook.chroot 2>/dev/null || true
# auto/config must stay NON-executable: this live-build version re-executes
# an executable auto/config from inside lb config, causing infinite
# recursion. It is kept in the repo as human-readable reference only.
chmod -x auto/config 2>/dev/null || true

echo "=== Installing live-build dependencies ==="
sudo apt-get update -qq
sudo apt-get install -y -qq live-build git cdebootstrap debootstrap syslinux-utils > /dev/null
# NOTE (2026-10-27): syslinux-utils on the HOST is kept for manual salvage
# only (running isohybrid by hand on a written ISO). The build-time fix is
# different: lb_binary_iso runs isohybrid INSIDE the chroot, so syslinux-utils
# is also in config/package-lists/haven.list.chroot. Attempt 13 wrote the
# full ISO (832128 extents, 1625 MB) inside the chroot and then died on the
# final hybrid step: "binary.sh: 5: isohybrid: not found".

echo "=== Cleaning any previous build ==="
sudo lb clean --purge 2>/dev/null || true
# Remove GENERATED config files (common/bootstrap/chroot/binary/source).
# lb config re-sources these when they exist, so a stale value written by an
# earlier run survives lb clean and overrides today's flags. Root cause of
# the 2026-10-17 job 52595 failure: an early ubuntu-mode lb config run wrote
# LB_KEYRING_PACKAGES="ubuntu-keyring" into config/chroot; every later
# debian-mode run re-sourced it, and lb chroot_archives then tried to
# install ubuntu-keyring from the Debian archive and died.
# Only the generated files are removed; the repo's config subdirectories
# (archives, hooks, includes.chroot, package-lists) are kept.
rm -f config/common config/bootstrap config/chroot config/binary config/source

echo "=== Applying HAVEN live-build configuration ==="
# Flags inlined (not via ./auto/config) to avoid the auto-execution
# recursion described above. Must match live-build/auto/config.
lb config \
  --mode debian \
  --distribution bookworm \
  --archive-areas "main contrib non-free non-free-firmware" \
  --parent-mirror-bootstrap http://deb.debian.org/debian/ \
  --parent-mirror-chroot http://deb.debian.org/debian/ \
  --parent-mirror-chroot-security http://security.debian.org/ \
  --parent-mirror-binary http://deb.debian.org/debian/ \
  --parent-mirror-binary-security http://security.debian.org/ \
  --parent-mirror-chroot-volatile http://deb.debian.org/debian/ \
  --parent-mirror-binary-volatile http://deb.debian.org/debian/ \
  --parent-mirror-debian-installer http://deb.debian.org/debian/ \
  --mirror-bootstrap http://deb.debian.org/debian/ \
  --mirror-chroot http://deb.debian.org/debian/ \
  --mirror-chroot-security http://security.debian.org/ \
  --mirror-binary http://deb.debian.org/debian/ \
  --mirror-binary-security http://security.debian.org/ \
  --mirror-chroot-volatile http://deb.debian.org/debian/ \
  --mirror-binary-volatile http://deb.debian.org/debian/ \
  --mirror-debian-installer http://deb.debian.org/debian/ \
  --parent-mirror-chroot-backports http://deb.debian.org/debian/ \
  --parent-mirror-binary-backports http://deb.debian.org/debian/ \
  --mirror-chroot-backports http://deb.debian.org/debian/ \
  --mirror-binary-backports http://deb.debian.org/debian/ \
  --debian-installer false \
  --bootloader syslinux \
  --iso-application "HAVEN" \
  --iso-publisher "Black Haven LLC" \
  --iso-volume "HAVEN_2026" \
  --security false \
  --backports true \
  --firmware-binary false \
  --firmware-chroot false \
  --keyring-packages debian-archive-keyring
# NOTE (2026-10-26): backports is TRUE because suricata is not in bookworm;
# it comes from bookworm-backports (7.0.10). zeek and python3-pipx are in
# neither bookworm nor backports, so they were removed from the package
# list (zeek needs its vendor apt repo; pipx needs a pip install hook).
# NOTE (2026-10-26): backports mirrors point at plain-HTTP deb.debian.org,
# not backports.debian.org: that host redirects HTTP to HTTPS, and the
# chroot has no CA certificates yet when apt runs, so the TLS handshake
# fails and the backports index never downloads (suricata then has no
# installation candidate). deb.debian.org serves the same
# bookworm-backports suite over plain HTTP.
# NOTE (2026-10-26): firmware flags are FALSE because live-build 3.0~a57's
# firmware stages (lb_chroot_linux-image, lb_binary_debian-installer)
# download dists/bookworm/Contents-amd64.gz to enumerate firmware packages,
# and Debian publishes Contents files per-component only (main/Contents-*),
# never at suite level -> 404 kills the build (job 52595, second failure).
# Firmware is named explicitly in config/package-lists/haven.list.chroot
# instead of auto-discovered.
# NOTE (2026-10-26): --debian-installer is FALSE because live-build 3.0~a57's
# lb_binary_debian-installer hardcodes packages that no longer exist in
# bookworm for amd64/debian mode: "lilo grub grub-pc" plus
# "linux-image-2.6-amd64" (2.6-era kernel name). apt fails on both and the
# stage aborts the build (attempt 8, after the squashfs was built). There
# is no config knob for those names; they live in live-build's own script.
# The ISO is therefore live-only with no Debian installer option. Revisit
# only with a newer live-build or a separately built installer.

echo "=== Patching Ubuntu live-build gfxboot assumption (debian mode) ==="
# NOTE (2026-10-27): Ubuntu's live-build (3.0~a57 + Ubuntu patches) ends
# lb_binary_syslinux with a gfxboot "bootlogo" repack block that runs
# unconditionally: (cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo.
# The bootlogo file is only ever created for ubuntu-mode gfxboot themes
# (extracted from gfxboot-theme-ubuntu near the top of the same script);
# debian-mode builds never create one, so the input redirect fails and
# the stage dies AFTER the splash conversion (attempt 12, 2026-10-27).
# Guard the extraction on the file existing; the repack line then writes
# a harmless empty bootlogo and the stage completes. The patch touches
# only the build host's script, is idempotent, and is reverted by
# reinstalling the live-build package.
LB_SYSLINUX_SCRIPT=/usr/lib/live/build/lb_binary_syslinux
if grep -qF '(cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo' "$LB_SYSLINUX_SCRIPT" \
   && ! grep -qF 'if [ -e ${_TARGET}/bootlogo ]' "$LB_SYSLINUX_SCRIPT"; then
  sudo sed -i 's|^(cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo$|if [ -e ${_TARGET}/bootlogo ]; then (cd "$tmpdir" \&\& cpio -i) < ${_TARGET}/bootlogo; fi|' "$LB_SYSLINUX_SCRIPT"
fi
grep -qF 'if [ -e ${_TARGET}/bootlogo ]' "$LB_SYSLINUX_SCRIPT" \
  || echo "WARNING: bootlogo guard not present in $LB_SYSLINUX_SCRIPT - the syslinux stage may fail at the gfxboot repack."

echo "=== Building HAVEN ISO (this takes 30-60 minutes) ==="
echo "Build started: $(date -u)"
sudo lb build 2>&1 | tee "$HOME/iso-build.log"

echo "=== Done: $(date -u) ==="
ls -lh ./*.iso 2>/dev/null || ls -lh ./*.hybrid.iso 2>/dev/null || echo "No ISO found - check $HOME/iso-build.log"
