#!/usr/bin/env bash

echo ""
echo "Checking for Pending certificates"

while : ; do
  sleep 5
  csrs=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}')

  if [[ "${csrs}" == "" ]]; then
    continue
  fi

  while IFS= read -r csr; do
    oc adm certificate approve "${csr}"
  done <<< "$csrs"
done
