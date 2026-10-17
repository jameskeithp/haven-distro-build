# HAVEN build system

Executable build tree for the flagship Linux distribution + AWS AMI.
Design authority: `../FLAGSHIP-LINUX-DISTRO-BUILD-GUIDE.md`.

## Layout

```
build/
  live-build/                 Debian live-build ISO tree (Phase 3)
    auto/config               lb config wrapper (run with sudo from live-build/)
    config/
      package-lists/haven.list.chroot   curated package list (Debian bookworm)
      hooks/live/0100-haven-hardening.hook.chroot   CIS-aligned hardening hook
      includes.chroot/        files overlaid into the live filesystem (mirrors /)
        etc/skel/.bashrc      default prompt + Layer 4 aliases
        etc/motd              authorized-use banner
        usr/local/bin/haven-healthcheck   lab health-check script
      archives/wazuh.list.chroot   Tier 2 Wazuh repo (UNTESTED, see file)
  packer/                     AWS AMI pipeline (Phase 4, not run here: no AWS creds)
    haven-ami.pkr.hcl         amazon-ebs template (Debian 12 base, Ansible + sanitize)
    scripts/sanitize.sh       image sanitize step (also inlined in the template)
  ansible/                    shared hardening as code (Phase 4)
    haven-harden.yml          playbook used by the Packer template
    roles/hardening/          reusable role: sysctl, sshd, auditd, packages
  ci/
    github-actions-build.yml  monthly ISO + AMI rebuild workflow (Phase 5)
  scripts/
    ami-smoke-test.sh         post-build AMI smoke test (STUB, untested)
```

## Design rule: one hardening codebase, two artifacts

`ansible/roles/hardening` is the source of truth. The live-build chroot hook
(`0100-haven-hardening.hook.chroot`) implements the same controls in shell for
build-time application; the Packer template applies the Ansible role to the AMI.
If a control changes, change the role first, then mirror it in the hook.

## ISO build quickstart (needs a Debian 12 host, 40GB free, root)

```bash
cd live-build
sudo apt-get install -y live-build debootstrap
sudo ./auto/config
sudo lb build 2>&1 | tee build.log
sha256sum haven-bookworm-amd64.hybrid.iso > SHA256SUMS
```

## Status (2026-10-17)

Scaffold complete. ISO build NOT attempted on this host (7.5GB free, need 15GB+).
No AWS actions taken. Nothing published.
