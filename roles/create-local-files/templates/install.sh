#!/usr/bin/env bash

# Exit on error, undefined variables and forward error through pipes
set -euo pipefail

# Define the expected domain for cluster
EXPECTED_HOSTNAME_DOMAIN="{{ cluster_name }}.{{ base_domain }}"

if [ $# -ge 1 ]; then
  # Manually provided hostname
  IGNITION_FILENAME="${1}.${EXPECTED_HOSTNAME_DOMAIN}"
else
  # Read existing hostname (from DHCP or DNS)
  CURRENT_HOSTNAME=$(hostname)
  CURRENT_HOSTNAME_DOMAIN=$(echo "${CURRENT_HOSTNAME}" | cut -d'.' -f 2-)

  # Validate that the current hostname is a fully qualified domain name (FQDN) matching the cluster domain.
  if [ "${CURRENT_HOSTNAME_DOMAIN}" != "${EXPECTED_HOSTNAME_DOMAIN}" ]; then
    echo "Error: The current hostname does not match the domain of the cluster."
    echo "The hostname must be a fully qualified domain name (FQDN)."
    echo "Hostname: ${CURRENT_HOSTNAME}"
    echo "Expected domain: ${EXPECTED_HOSTNAME_DOMAIN}"
    exit 1
  fi

  IGNITION_FILENAME="${CURRENT_HOSTNAME}"
fi

# Create full url for ignition file
IGNITION_FILE_URL="http://{{ groups['lbs'][0] }}:8080/${IGNITION_FILENAME}.ign"

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
