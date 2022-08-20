#!/usr/bin/env bash

while : ; do
  sleep 5
  echo ""
  echo "Checking for Pending certificates"
  csr=$(oc get csr -o json | jq -r '[.items[] | select(.status == {}) | .] | .[0].metadata.name')

  if [[ "${csr}" == "null" ]]; then
    echo "No CSR found"
    continue
  fi

  echo "Found CSR: ${csr}"
  oc adm certificate approve "${csr}"
done
