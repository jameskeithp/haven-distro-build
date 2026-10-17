#!/bin/bash
set -e
# HAVEN AMI sanitize step. One-way destructive sequence; shell on purpose.
# Runs as root on the build instance, last provisioner before Packer snapshots.
# Same content is referenced by packer/haven-ami.pkr.hcl (provisioner "shell" script).
# Source: Phase 4.1 of FLAGSHIP-LINUX-DISTRO-BUILD-GUIDE.md. NOT executed here.

echo '--- sanitizing image ---'
# SSH host keys: MUST be regenerated on first boot, never baked in
rm -f /etc/ssh/ssh_host_*
# Machine identity: cloud-init regenerates these
rm -f /etc/machine-id && touch /etc/machine-id
rm -f /var/lib/dbus/machine-id
# cloud-init state and logs from the build
cloud-init clean --logs --seed
rm -rf /var/log/cloud-init* /var/log/*.log /var/log/*.gz
# Shell histories and temp credentials anywhere on disk
rm -f /root/.bash_history /home/admin/.bash_history
rm -rf /tmp/* /var/tmp/*
find / -maxdepth 4 -name '*.pem' -o -name 'id_rsa*' 2>/dev/null | grep -v -E '^/(usr|etc)/' | xargs -r rm -f
# Package cache: smaller AMI, no stale metadata
apt-get clean && rm -rf /var/lib/apt/lists/*
# Bash history suppression for any future build shells
ln -sf /dev/null /root/.bash_history
echo '--- sanitize complete ---'
sync
