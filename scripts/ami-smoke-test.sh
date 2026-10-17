#!/bin/bash
set -e
# HAVEN AMI smoke test. STUB: logic sketched, not tested (no AWS access here).
# Called by the CI workflow after `packer build` with the new AMI ID.
# Real implementation: launch instance from AMI, wait for SSM registration,
# run `haven-healthcheck` via SSM, terminate the instance, fail on any FAIL.
AMI_ID="${1:?usage: ami-smoke-test.sh <ami-id>}"
echo "STUB: would smoke-test ${AMI_ID} via SSM (launch, healthcheck, terminate)."
echo "Not implemented: requires AWS credentials and the haven-packer-builder role."
exit 0
