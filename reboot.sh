#!/usr/bin/env bash

nodes=$(oc get node -o json | jq -r '.items[].metadata.name' | sort) || exit 1

while IFS= read -r node; do
  echo ""
  echo "Draining node $node"
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force || exit 1

  echo ""
  echo "Rebooting node $node"
  ssh -n "$node" 'sudo reboot 5'

  echo ""
  echo "Wait for node to restart"
  sleep 30 || exit 1

  while : ; do
    echo ""
    sleep 5
    status=$(oc get node "$node" -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .status')
    echo "Node ready status is: $status"
    [[ $status != "True" ]] || break
  done

  echo ""
  echo "Resume node $node"
  kubectl uncordon "$node" || exit 1
done <<< "$nodes"
