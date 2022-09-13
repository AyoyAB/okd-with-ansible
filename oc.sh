#!/usr/bin/env bash
#
# Run oc with kubeconfig file
#

# Exit on error, undefined variables and forward error through pipes
set -euo pipefail

# Set WORKSPACE to <current dir of entry script> if not already defined
WORKSPACE=${WORKSPACE:-"$(
  cd "$(dirname "$0")"
  pwd -P
)"}

OC_CLIENT="${WORKSPACE}/openshift-client/oc"
KUBECONFIG_FILE="${WORKSPACE}/openshift-files/auth/kubeconfig"

if ! [ -f "${OC_CLIENT}" ]; then
  echo >&2 "oc executable is not installed"
  exit 1
fi

if ! [ -f "${KUBECONFIG_FILE}" ]; then
  echo >&2 "kubeconfig file is missing"
  exit 1
fi

exec "${OC_CLIENT}" --kubeconfig "${KUBECONFIG_FILE}" "$@"
