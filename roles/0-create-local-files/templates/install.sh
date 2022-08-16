#!/usr/bin/env bash

# Exit on error, undefined variables and forward error through pipes
set -euo pipefail

# Read existing hostname (from DHCP)
IGNITION_FILE_HOSTNAME=$(hostname | cut -d'.' -f1)

if [ $# -ge 1 ]; then
  # Manually provided hostname
  IGNITION_FILE_HOSTNAME="${1}"
fi

IGNITION_FILE_URL="http://{{ groups['infras'][0] }}:8080/${IGNITION_FILE_HOSTNAME}.{{ cluster_name }}.{{ base_domain }}.ign"

echo ""
echo "Installation will use the following ignition file:"
echo "${IGNITION_FILE_URL}"
echo ""
read -n 1 -s -r -p "--- Press any key continue ---"

# Install CoreOS with ignition file
sudo coreos-installer \
  install \
  /dev/sda \
  --firstboot-args='console=tty0 rd.neednet=1 rd.net.timeout.carrier=30' \
  --insecure-ignition \
  --ignition-url="${IGNITION_FILE_URL}"

# Reboot machine after install
echo ""
read -n 1 -s -r -p "--- Remove the bootable media, then press any key to reboot ---"
sudo reboot now
