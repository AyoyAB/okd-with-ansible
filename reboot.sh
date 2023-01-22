#!/usr/bin/env bash
#
# Reboot cluster nodes safely ony by one
#

set -euo pipefail

#
SSH_KEY=~/.ssh/id_ansible

#
# Gracefully cycle a node
# - Drain
# - Reboot or Shutdown
# - Wait for node to be ready again
# -
#
_cycle_node() {
  local _NODE_NAME="${1}"
  local _SHUTDOWN="${2}"

  echo ""
  echo "Draining node ${_NODE_NAME}"
  oc adm drain "${_NODE_NAME}" --ignore-daemonsets --delete-emptydir-data || echo Failed to drain. Forcing
  oc adm drain "${_NODE_NAME}" --ignore-daemonsets --delete-emptydir-data --force

  echo ""
  if [ "${_SHUTDOWN}" == "Y" ]; then
    ACTION="--poweroff"
    echo "Shutting down node ${_NODE_NAME}"
  else
    ACTION="--reboot"
    echo "Rebooting node ${_NODE_NAME}"
  fi

  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${SSH_KEY} -n "core@${_NODE_NAME}" "sudo shutdown +0 ${ACTION} && exit" \
    || echo "Returned error: $?"

  echo ""
  echo "Waiting for node to be restarted"
  sleep 30 || exit 1

  # Wait forever until node is Ready again
  while : ; do
    echo ""
    sleep 5
    status=$(oc get node "${_NODE_NAME}" -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
    echo "Node ready status is: $status"
    [[ $status != "True" ]] || break
  done

  echo ""
  echo "Resume node ${_NODE_NAME}"
  oc adm uncordon "${_NODE_NAME}" || exit 1
}

_main() {
  #
  # Get parameters
  #

  local _SHUTDOWN="N"

  local _MANUAL_NODES=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--shutdown)
        _SHUTDOWN="Y"
        shift # past argument
        ;;
      -h|--help)
        echo "$0 [-h --help] [-s --shutdown] [nodes...]"
        exit 0
        ;;
      --*|-*)
        >&2 echo "Error: Unknown option ${1}"
        exit 1
        ;;
      *)
        _MANUAL_NODES+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done

  # Get all nodes from cluster
  local _ALL_NODES
  _ALL_NODES=$(oc get node -o json | jq -r '.items[].metadata.name' | sort) || exit 1

  # Cycle all nodes by default
  local _CYCLE_NODES
  _CYCLE_NODES="${_ALL_NODES}"

  if [ -n "${_MANUAL_NODES:-}" ]; then
    # Use only manually provided nodes if provided
    _CYCLE_NODES=()

    # Ensure all manually provided nodes are part of cluster
    for _MANUAL_NODE in "${_MANUAL_NODES[@]}"; do
      local _IN_CLUSTER

      while IFS= read -r _NODE; do
        if [ "${_MANUAL_NODE}" == "${_NODE}" ]; then
          _IN_CLUSTER="Y"
          break
        fi
      done <<< "${_ALL_NODES}"

      if [ "${_IN_CLUSTER}" == "Y" ]; then
        # Part of cluster
        _CYCLE_NODES+=("${_MANUAL_NODE}")
      else
        # Not part of cluster
        >&2 echo "Error: The provided node (${_MANUAL_NODE}) is not part of the cluster."
        exit 1
      fi

    done

  fi

  # Print warning
  printf "The following nodes will be cycled ("
  if [ "${_SHUTDOWN}" == "Y" ]; then
    printf "shutdown"
  else
    printf "reboot"
  fi
  printf ") in order:\n"
  echo "${_CYCLE_NODES[@]}"
  echo "---"

  # Ask for verification
  read -r -p "Continue (y/n)?" _IM_SURE
  case "${_IM_SURE}" in
    y|Y )
      echo ""
      ;;
    n|N )
      echo "Exiting..."
      exit 1
      ;;
    *)
      >&2 echo "Error: Invalid choice ${_IM_SURE}"
      exit 1
      ;;
  esac

  echo "---"

  # Perform reboot/shutdown cycle of all the provided nodes
  while IFS= read -r _NODE; do
    _cycle_node "${_NODE}" "${_SHUTDOWN}"
  done <<< "${_CYCLE_NODES[@]}"
}

#

_main "$@"
