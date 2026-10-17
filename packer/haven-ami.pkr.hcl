# HAVEN AMI Packer template. Source: Phase 4.1 of FLAGSHIP-LINUX-DISTRO-BUILD-GUIDE.md.
# Run: packer init haven-ami.pkr.hcl && packer validate haven-ami.pkr.hcl && packer build haven-ami.pkr.hcl
# Needs AWS credentials (SSO recommended). NOT run in this environment.
# NOTE: Debian AMI owner ID 136693071363 and the CloudWatch agent URL are
# flagged "verify at build time" in the guide.

packer {
  required_plugins {
    amazon  = { source = "github.com/hashicorp/amazon",  version = ">= 1.2.8" }
    ansible = { source = "github.com/hashicorp/ansible", version = ">= 1.1.0" }
  }
}

variable "region"      { type = string default = "us-east-1" }
variable "ami_version" { type = string default = "2026.10" }

# Debian 12 (Bookworm) official AMI, x86_64, EBS-backed, HVM
source "amazon-ebs" "haven" {
  region        = var.region
  instance_type = "t3.medium"          # enough headroom for Ansible + hardening
  ssh_username  = "admin"              # Debian official AMIs use 'admin'

  source_ami_filter {
    filters = {
      name                = "debian-12-amd64-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["136693071363"]     # Debian official; verify at build time
    most_recent = true
  }

  ami_name        = "haven-${var.ami_version}-debian12-amd64"
  ami_description = "HAVEN Linux ${var.ami_version}: CIS-aligned, cloud-hardened image for infrastructure and security engineering."

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true       # encrypted by default; non-negotiable
  }

  # ENA is default on modern AMIs; this tag documents intent for reviewers
  ena_support = true

  tags = {
    Name    = "haven-${var.ami_version}"
    Product = "haven-linux"
    CIS     = "level1-aligned"
  }
}

build {
  sources = ["source.amazon-ebs.haven"]

  # 1. Base packages + Tier 2 repo, then the full hardening playbook
  provisioner "ansible" {
    playbook_file   = "../ansible/haven-harden.yml"
    extra_arguments = ["--extra-vars", "haven_version=${var.ami_version}"]
  }

  # 2. AWS-native agents (kept as shell so the AMI works even if Ansible changes)
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      # SSM Agent: Debian package from AWS
      "sudo apt-get install -y amazon-ssm-agent",
      "sudo systemctl enable amazon-ssm-agent",
      # CloudWatch agent: official DEB from AWS (arch-specific URL; verify at build time)
      "curl -fsSL -o /tmp/amazon-cloudwatch-agent.deb https://amazoncloudwatch-agent.s3.amazonaws.com/debian/amd64/latest/amazon-cloudwatch-agent.deb",
      "sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb || sudo apt-get install -f -y",
      "rm -f /tmp/amazon-cloudwatch-agent.deb"
    ]
  }

  # 3. SANITIZE: linear shell, read top to bottom (see scripts/sanitize.sh, same content)
  provisioner "shell" {
    script = "scripts/sanitize.sh"
  }
}
