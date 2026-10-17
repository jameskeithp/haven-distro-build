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
sudo apt-get install -y -qq live-build git cdebootstrap debootstrap > /dev/null

echo "=== Cleaning any previous build ==="
sudo lb clean --purge 2>/dev/null || true

echo "=== Applying HAVEN live-build configuration ==="
# Flags inlined (not via ./auto/config) to avoid the auto-execution
# recursion described above. Must match live-build/auto/config.
lb config \
  --distribution bookworm \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --bootloader syslinux \
  --iso-application "HAVEN" \
  --iso-publisher "Black Haven LLC" \
  --iso-volume "HAVEN_2026" \
  --security true \
  --backports false \
  --firmware-binary true \
  --firmware-chroot true

echo "=== Building HAVEN ISO (this takes 30-60 minutes) ==="
echo "Build started: $(date -u)"
sudo lb build 2>&1 | tee "$HOME/iso-build.log"

echo "=== Done: $(date -u) ==="
ls -lh ./*.iso 2>/dev/null || ls -lh ./*.hybrid.iso 2>/dev/null || echo "No ISO found - check $HOME/iso-build.log"
