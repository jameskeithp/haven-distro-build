#!/bin/bash
# HAVEN ISO build runner - execute on the build host (Ubuntu 24.04, 50GB+ disk).
# Usage: ./run-iso-build.sh   (runs detached via nohup; watch ~/iso-build.log)
set -e
cd "$(dirname "$0")/live-build"

echo "=== Installing live-build dependencies ==="
sudo apt-get update -qq
sudo apt-get install -y -qq live-build git cdebootstrap debootstrap > /dev/null

echo "=== Cleaning any previous build ==="
sudo lb clean --purge 2>/dev/null || true

echo "=== Building HAVEN ISO (this takes 30-60 minutes) ==="
echo "Build started: $(date -u)"
sudo lb build 2>&1 | tee "$HOME/iso-build.log"

echo "=== Done: $(date -u) ==="
ls -lh ./*.iso 2>/dev/null || ls -lh ./*.hybrid.iso 2>/dev/null || echo "No ISO found - check $HOME/iso-build.log"
