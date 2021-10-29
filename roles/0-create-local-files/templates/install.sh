#!/usr/bin/env bash
if [ $# -eq 0 ]
  then
    echo "Supply the hostname as argument, for exampel master1"
    exit 1
fi

sudo coreos-installer \
    install \
    /dev/sda \
    --firstboot-args='console=tty0 rd.neednet=1 rd.net.timeout.carrier=30' \
    --insecure-ignition \
    --ignition-url=http://{{ groups['infras'][0] }}.{{ cluster_name }}.{{ base_domain }}:8080/$1.ign
