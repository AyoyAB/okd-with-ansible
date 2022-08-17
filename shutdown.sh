#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ansible -i "${SCRIPT_DIR}/hosts" masters -m raw -a "/usr/sbin/shutdown 5" --become
ansible -i "${SCRIPT_DIR}/hosts" nodes   -m raw -a "/usr/sbin/shutdown 5" --become
