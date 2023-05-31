#!/usr/bin/env bash
#
# Reboot cluster nodes safely ony by one
#

set -euo pipefail

#
SSH_KEY=~/.ssh/id_ansible


#
# Wait for node to have a specific status
#
_wait_for_node_ready_status() {
  local _NODE_NAME="${1}"
  local _WAIT_READY_STATUS="${2}"

  while : ; do
    # Get Ready status for node
    local _STATUS
    if ! _STATUS=$(oc get node "${_NODE_NAME}" -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .status'); then
      >&2 echo "Error, exit code from oc: $?"
    else
      echo "Node ready status is: ${_STATUS}"

      if { [ "${_WAIT_READY_STATUS}" == "Y" ] && [ "${_STATUS}" == "True" ]; } ||
         { [ "${_WAIT_READY_STATUS}" == "N" ] && { [ "${_STATUS}" == "False" ] || [ "${_STATUS}" == "Unknown" ]; } }; then
        # Break retry loop when expected status is reached
        break
      fi
    fi

    # Sleep before trying again
    sleep 5
  done
}

#
# Select y/n to continue or not
#
_verify_continue() {
  local _QUESTION="${1}"

  while true; do
    read -r -p "${_QUESTION} [y/n] " _CHOICE
    case "${_CHOICE}" in
      y|Y )
        return 0
        ;;
      n|N )
        echo "Exiting..."
        exit 1
        ;;
      * )
        echo "Error: Invalid choice ${_CHOICE}"
        ;;
    esac
  done
}

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
  local _USE_SSH="${3}"

  echo ""
  echo "Draining node ${_NODE_NAME}"
  oc adm drain "${_NODE_NAME}" --ignore-daemonsets --delete-emptydir-data || echo Failed to drain. Forcing
  oc adm drain "${_NODE_NAME}" --ignore-daemonsets --delete-emptydir-data --force

  echo ""
  local _ACTION
  if [ "${_SHUTDOWN}" == "Y" ]; then
    _ACTION="--poweroff"
    echo "Shutting down node ${_NODE_NAME}"
  else
    _ACTION="--reboot"
    echo "Rebooting node ${_NODE_NAME}"
  fi

  local _SHUTDOWN_CMD="shutdown +0 ${_ACTION}"

  if [ "${_USE_SSH}" == "Y" ]; then
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${SSH_KEY} -n "core@${_NODE_NAME}" "${_SHUTDOWN_CMD} && exit" \
        || echo "Returned error: $?"
  else
    oc debug "node/${_NODE_NAME}" -- chroot /host sh -c "sleep 5; ${_SHUTDOWN_CMD}" || echo "Returned error: $?"
  fi

  echo ""
  echo "Waiting for node ${_NODE_NAME} to be NotReady (Rebooting/Powered off/Offline)"
  _wait_for_node_ready_status "${_NODE_NAME}" "N"

  echo ""
  echo "Waiting for node ${_NODE_NAME} to be Ready (Rebooted/Powered on/Online) again"
  _wait_for_node_ready_status "${_NODE_NAME}" "Y"

  echo ""
  echo "Resume node ${_NODE_NAME}"
  oc adm uncordon "${_NODE_NAME}" || exit 1
}

#
# Print usage
#
_usage() {
  echo "Usage: $0 [-h --help] [-s --shutdown] [-u --use-ssh] [nodes...]"
}

_main() {
  #
  # Get parameters
  #

  local _SHUTDOWN="N"
  local _USE_SSH="N"

  local _MANUAL_NODES=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--shutdown)
        _SHUTDOWN="Y"
        shift # past argument
        ;;
      -u|--use-ssh)
        _USE_SSH="Y"
        shift # past argument
        ;;
      -h|--help)
        _usage
        exit 0
        ;;
      --*|-*)
        >&2 echo "Error: Unknown option ${1}"
        >&2 _usage
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
  _verify_continue "Continue?"
  echo "---"

  # Perform reboot/shutdown cycle of all the provided nodes
  while IFS= read -r _NODE; do
    _cycle_node "${_NODE}" "${_SHUTDOWN}" "${_USE_SSH}"
  done <<< "${_CYCLE_NODES[@]}"
}

#

_main "$@"
