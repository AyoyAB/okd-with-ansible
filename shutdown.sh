#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ansible -i "${SCRIPT_DIR}/hosts" masters --become  -a "/usr/sbin/shutdown 5"
ansible -i "${SCRIPT_DIR}/hosts" nodes   --become  -a "/usr/sbin/shutdown 5"
