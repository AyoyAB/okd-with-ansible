#!/usr/bin/env bash

# Exit on error, undefined variables and forward error through pipes
set -euo pipefail

# Set WORKSPACE to <current dir of entry script> if not already defined
WORKSPACE=${WORKSPACE:-"$(
  cd "$(dirname "$0")"
  pwd -P
)"}

OC_CLIENT="${WORKSPACE}/openshift-client/oc"

# Set default KUBECONFIG
KUBECONFIG="${KUBECONFIG:-~/.kube/config}"

node_is_in_cluster() {
  local _NAME="${1}"

  local _OUTPUT
  _OUTPUT=$("${OC_CLIENT}" \
    --kubeconfig "${KUBECONFIG}" \
    get nodes \
    --field-selector metadata.name="${_NAME}" \
    -o json |
    jq '.items | length')

  # Exit code 0 if _OUTPUT is "1"
  [ "${_OUTPUT}" == "1" ]
}

approve_pending_certificate_requests() {
  local _PENDING_CSR_IDS
  _PENDING_CSR_IDS=$("${OC_CLIENT}" \
    --kubeconfig "${KUBECONFIG}" \
    get csr \
    -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}')

  if [ "${_PENDING_CSR_IDS}" == "" ]; then
    echo "No pending certificate requests"
    return
  fi

  echo "Approving pending certificate requests..."

  while IFS= read -r _CSR_ID; do
    # || true is due to this script being run in parallell,
    # and another script already having approved a csr
    "${OC_CLIENT}" \
      --kubeconfig "${KUBECONFIG_FILE}" \
      adm certificate approve "${_CSR_ID}" || true
  done <<<"$_PENDING_CSR_IDS"
}

if [ -n "${1:-}" ]; then
  # Node specified,
  # Check if node is in cluster,
  # If not, accept pending certificate requests
  # Repeat X times

  _NODE="${1}"

  # Set default number of attempts
  _ATTEMPTS="${2:-3}"

  while true; do
    echo "Checking if node ${_NODE} is in cluster"

    if node_is_in_cluster "${_NODE}"; then
      echo "Node ${_NODE} is in cluster!"
      echo "Stopping!"
      exit 0
    fi

    echo "Node ${_NODE} is not in cluster."

    _ATTEMPTS=$((_ATTEMPTS - 1))
    if [ "${_ATTEMPTS}" -le 0 ]; then
      echo >&2 "Attempts exhausted, please run script again!"
      exit 1
    fi

    approve_pending_certificate_requests
    sleep 2
  done
else
  # No parameters, loop and accept pending certificate requests forever
  while true; do
    approve_pending_certificate_requests
    sleep 5
  done
fi
