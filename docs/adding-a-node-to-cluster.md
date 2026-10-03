# Adding a node to the cluster

This describes how to add a node to a running cluster, for example
a new worker or a worker that failed during an agent-based
installation. The agent ISO used to install the cluster cannot be
used for this. Instead, `oc adm node-image create` builds an ISO
from the running cluster for the specific nodes to add.

The examples use worker2 from `inventories/example-scos-agent`.
All commands are run from the repository root.

## Prerequisites

- `oc` 4.17 or later (`./openshift-client/oc` from the playbook).
- A kubeconfig for the cluster:

  ```shell
  export KUBECONFIG=openshift-files/okd4.example.com/.install-config/auth/kubeconfig
  ```

- DHCP gives the node its address and hostname, and DNS resolves
  the hostname, just like for the other nodes.
- Secure Boot is disabled in the node's firmware. SCOS 10 kernels
  fail to boot with Secure Boot enabled ("bad shim signature"),
  see https://github.com/okd-project/okd/issues/1938.
- If the node has been used before, the disk does not need to be
  wiped. The installation overwrites it.

## 1. Describe the node

Find the node's MAC address, the name of its network interface,
and the disk to install on. For worker2 these are `eno1`,
`1c:69:7a:a2:50:ce` and `/dev/nvme0n1`.

Create `openshift-files/okd4.example.com/add-nodes/nodes-config.yaml`:

```yaml
hosts:
  - hostname: worker2.okd4.example.com
    rootDeviceHints:
      deviceName: /dev/nvme0n1
    interfaces:
      - name: eno1
        macAddress: 1c:69:7a:a2:50:ce
    networkConfig:
      interfaces:
        - name: eno1
          type: ethernet
          state: up
          mac-address: 1c:69:7a:a2:50:ce
          ipv4:
            enabled: true
            dhcp: true
```

Several nodes can be listed under `hosts`, and they can all boot
from the same ISO.

For a single node using DHCP, the file can be skipped and the
values given as flags instead (see the next step).

## 2. Create the ISO

```shell
./openshift-client/oc adm node-image create \
  --dir=openshift-files/okd4.example.com/add-nodes \
  -o worker2.x86_64.iso
```

Or, without `nodes-config.yaml`:

```shell
./openshift-client/oc adm node-image create \
  --dir=openshift-files/okd4.example.com/add-nodes \
  --mac-address=1c:69:7a:a2:50:ce \
  --root-device-hint=deviceName:/dev/nvme0n1 \
  -o worker2.x86_64.iso
```

The command starts a pod in a temporary namespace in the cluster
and downloads the ISO into the `--dir` directory. It takes a few
minutes. If it fails, the details are in `report.json` in the same
directory.

The ISO contains credentials for joining this cluster. Keep it to
yourself and create a new one when it is needed again.

## 3. Boot the node from the ISO

1. Write the ISO to a USB stick, for example with balenaEtcher.
2. Boot the node from the stick. Choose the UEFI entry for the
   stick in the firmware's boot menu.

The node installs SCOS to the disk and reboots. After the first
boot it switches to the cluster's OS image and reboots once more.

## 4. Follow the progress

```shell
./openshift-client/oc adm node-image monitor --ip-addresses 192.168.60.185
```

The command reports when the node has been installed and when it
waits for certificate signing requests to be approved.

## 5. Approve the certificate signing requests

The node requests two certificates, a minute or two apart. Approve
each one when it shows up as pending:

```shell
./openshift-client/oc get csr | grep Pending
./openshift-client/oc adm certificate approve <csr-name>
```

## 6. Verify

```shell
./openshift-client/oc get nodes
```

The node should be listed as `Ready` with the expected role.
Operators that need pods on several workers, such as ingress and
monitoring, then recover on their own.

Finally, add the node to the inventory's `hosts` file with its
`mac_address`, so that the next installation includes it:

```ini
[workers]
worker2.okd4.example.com mac_address=1c:69:7a:a2:50:ce
```
