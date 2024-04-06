#!/usr/bin/env bash
#
# Reboot cluster nodes safely ony by one
#

set -euo pipefail

oc adm reboot-machine-config-pool mcp/master mcp/worker
oc adm wait-for-node-reboot nodes --all
