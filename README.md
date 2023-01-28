# OKD with ansible

This repository holds ansible files for installing
OKD using Ansible on hardware.

[Installing a user-provisioned cluster on bare metal](https://docs.okd.io/latest/installing/installing_bare_metal/installing-bare-metal.html)

It assumes you have the following hardware:

1. A debian server (e.g. Raspberry PI) for infrastructure (load balancing and serving the ignition files)
2. An intel machine that will first serve as bootstrap (can be the same as the machine that will later serve as worker1).
3. 3 master intel machines.

If you have more hardware, adjust the inventory file accordingly.

NOTE: If you want to run a different version of OKD, extract
the installer under ./openshift-install which will stop retrieving the installer.
The exact command to extract the installer is available per beta version at
[OKD Nightly Releases](https://amd64.origin.releases.ci.openshift.org/#4.8.0-0.okd).

There are optional components to install which are controlled by
ansible variables. These are defined in the inventory group vars.

| variable                            | description                                                                                        |
|-------------------------------------|----------------------------------------------------------------------------------------------------|
| argocd                              | whether to install the argocd operator                                                             |
| sealed_secrets                      | Whether to pre-install a secret for sealed_secret to make sure git sealed secrets can be decrypted | 
| set_etc_hostname_in_ignition_file   | Whether to set the hostname in /etc/hostname                                                       |
| use_control_plane_nodes_for_compute | Whether to allow masters to be used for regular pods                                               |

# Disconnected registry

In disconnected environments you normally have a docker registry which will supply all the OKD images.

To use a disconnected registry, set the following parameters:

| variable                                            | description                                                                                                          |
|-----------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| use_disconnected_registry                           | Indicating a registry should be used. Example: true                                                                  |
| disconnected_registry_trust_bundle_file             | Filename of the root CA for the registry. Example: ./openshift-ca/example.crt                                        |
| disconnected_registry_quay_io_openshift_okd         | URL to the registry for quay.io/openshift/okd. Example: registry.okd4.example.com:5011/openshift/okd                 |
| disconnected_registry_quay_io_openshift_okd_content | URL to the registry for quay.io/openshift/okd-content. Example: registry.okd4.example.com:5011/openshift/okd-content |                                           

# Pull-through-cache

In disconnected environments you normally have a docker registry which will supply all the OKD images. The
pull-through-cache will simulate that and should also, if you have a faster cache than your Internet connection,
improve your installation time.

There is a `Makefile` under `hack/docker-proxy` that can create the certificates and docker containers needed for that.
The certificates will be placed under `openshift-ca` and will need to be copied to the docker machine. Note that
the hostname `registry.okd4.example.com` needs to be setup in DNS.

| Usage          | description                                     |
|----------------|-------------------------------------------------|
| make ca        | creates both CA and registry certificates       |
| make quay.io   | creates the docker proxy registry for quay.io   |
| make docker.io | creates the docker proxy registry for docker.io |

# Preparation

1. Pull your [RedHat pull secret](https://console.redhat.com/openshift/install/metal/user-provisioned) and place in file `pull-secret`.
2. [If you want github integration](https://docs.openshift.com/container-platform/4.8/authentication/identity_providers/configuring-github-identity-provider.html),
   create a file called "github-config.json" with similar content as this:
   ```json
   {
     "clientID": "< github client ID >",
     "clientSecret": "< github client secret >",
     "organizations": [
       "< your github organization >"
     ]
   }
   ```
3. Set up DNS with the following entries (of course, adjust
   addresses to your infrastructure):

   | hostname                       | Address                        |
   |--------------------------------|--------------------------------| 
   | infra1.okd4.example.com        | 192.168.60.180                 |
   | api-int.okd4.example.com       | CNAME infra1.okd4.example.com  |
   | api.okd4.example.com           | CNAME infra1.okd4.example.com  |
   | apps.okd4.example.com          | CNAME infra1.okd4.example.com  |
   | *.apps.okd4.example.com        | CNAME infra1.okd4.example.com  |
   | master1.okd4.example.com       | 192.168.60.181                 |
   | master2.okd4.example.com	    | 192.168.60.182                 |
   | master3.okd4.example.com	    | 192.168.60.183                 |
   | worker1.okd4.example.com       | 192.168.60.184                 |

   If you're using pihole (as I do), increase rate limiting, create `/etc/dnsmasq.d/99-openshift.conf`
   with the following content and restart dns (`pihole restartdns`)
   ```
   address=/.apps.okd4.example.com/192.168.60.180
   ```

   If your DNS cannot handle wildcards, add these entries as CNAME, pointing to app.okd4.example.com:

   - alertmanager-main-openshift-monitoring.apps.okd4.example.com 
   - canary-openshift-ingress-canary.apps.okd4.example.com
   - console-openshift-console.apps.okd4.example.com
   - downloads-openshift-console.apps.okd4.example.com
   - grafana-openshift-monitoring.apps.okd4.example.com
   - oauth-openshift.apps.okd4.example.com
   - prometheus-k8s-openshift-monitoring.apps.okd4.example.com
   - thanos-querier-openshift-monitoring.apps.okd4.example.com

4. Create a new image for the rasperry pi with enabled ssh and boot it up.
5. Create a bootable USB from the correct version of Fedora CoreOS.  
   (At the time of writing, the current working release is
   [36.20220716.3.1](https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20220716.3.1/x86_64/fedora-coreos-36.20220716.3.1-live.x86_64.iso))

   ```shell
   ./openshift-install/openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats.iso.disk.location'
   ```
6. Set up static DHCP entries for the machines, matching IP addresses above.

# Run playbook

It's time to run the playbook. There are a number of steps
that will be completed:

1. Cluster configuration will be created and added into
   ignition files.
2. The infrastructure node (RPI) will be setup.

This is how to run the playbook:

```shell
make dependencies
CLUSTER_NAME=example make cluster
```

Or if you wish to run the playbook directly:

```shell
ansible-playbook -i inventories/example -v deploy-okd.yml --extra-vars "use_control_plane_nodes_for_compute=true argocd=true"
```

Once the playbook tell you to, boot the masters on Fedora CoreOS USB.

To switch keyboard mapping on CoreOS, do the following:

```shell
$ sudo localectl set-keymap se
```

Then start the installation process.

```shell
# Use hostname from DHCP or DNS
$ bash -c "$(curl -fsSL http://infra1.okd4.example.com:8080/install.sh)"
```

```shell
# Manually set hostname
$ bash -c "$(curl -fsSL http://infra1.okd4.example.com:8080/install.sh)" -s master[1-3]
```

Once the installation has finished, remove the bootable media and reboot.

Verify that the master is trying to pull the secondary ignition from `https://api-int.okd4.example.com:22623`.

Once all masters are waiting for the secondary ignition, continue the playbook
which tell you to boot the first worker machine on
Fedora CoreOS USB and start the installation for the bootstrap process:

```shell
# Use hostname from DHCP or DNS
$ bash -c "$(curl -fsSL http://infra1.okd4.example.com:8080/install.sh)"
```

```shell
# Manually set hostname
$ bash -c "$(curl -fsSL http://infra1.okd4.example.com:8080/install.sh)" -s bootstrap
```

Once the installation has finished, remove the bootable media and reboot.

After some time, you will be able to login via ssh to the bootstrap machine
and follow the installation:

```shell
$ ssh core@worker1.okd4.example.com
The authenticity of host 'worker1.okd4.example.com (192.168.60.184)' can't be established.
ECDSA key fingerprint is SHA256:Z3edOf5ImnxO/x9tchkto5LoEQIaFm8DT/7zyGj5r6g.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'worker1.okd4.example.com,192.168.60.183' (ECDSA) to the list of known hosts.
This is the bootstrap node; it will be destroyed when the master is fully up.

The primary services are release-image.service followed by bootkube.service. To watch their status, run e.g.

  journalctl -b -f -u release-image.service -u bootkube.service
Fedora CoreOS 34
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/c/server/coreos/

Last login: Sat Sep  4 05:55:40 2021 from 192.168.40.50
[core@nucbootstrap ~]$ journalctl -b -f -u release-image.service -u bootkube.service
```

When the installation has started, continue the playbook.
When the playbook detects that the installation is finished, the playbook will continue with post-installation configuration.

You can now open the cluster console by
opening https://console-openshift-console.apps.okd4.example.com.

Have fun with your cluster!

## Adding the bootstrap or any other node to the cluster

Once the cluster has been correctly installed, shutdown the
bootstrap node, remove the partitions and reinstall using
this command:

```shell
# Use the generic ignition file for the role, "master" or "worker"
$ bash -c "$(curl -fsSL http://infra1.okd4.example.com:8080/install.sh)" -s worker
```

Since this has not been prepared in the cluster earlier,
you need to approve the certificate requests.

This is easiest done with the `issueCertificates.sh` script. Note that there is normally three certificate per node.

```shell
$ ./issueCertificates.sh
./issueCertificates.sh                                                                                           
No pending certificate requests
...
No pending certificate requests
No pending certificate requests
Approving pending certificate requests...
certificatesigningrequest.certificates.k8s.io/csr-qmkv6 approved
No pending certificate requests
Approving pending certificate requests...
certificatesigningrequest.certificates.k8s.io/csr-wfnjq approved
certificatesigningrequest.certificates.k8s.io/csr-qftjq approved
No pending certificate requests
```
