# Renewing expired master certificates

I often reinstall the cluster, make my tests and shut it down. Since the node certificates are initially only valid for
roughly 25 hours, when I start up the cluster a couple of days later, they have expired and the API server cannot be
reached.

Check when your certificates expire:
```
oc -n openshift-kube-apiserver-operator \
    get secret kube-apiserver-to-kubelet-signer \
    -o jsonpath='{.metadata.annotations.auth\.openshift\.io/certificate-not-after}'
```

This is how to renew the certificate on the masters.

## If the API-server responds
For certain versions of OKD the API-server on masters still boots up correctly and responds to kubectl. That makes
it easy to renew the certificates using the script `issueCertificates.sh`.

## If the API-server does not respond

However, there are situations when the API server does not respond due to expired certificates and
we need to get at least one master up and running to approve the other master certificates.

Login using SSH and become root:

```
$ ssh core@master1.okd4.example.com
$ sudo -i
```

There is normally an automatically generated CSR waiting. Configure oc and approve the CSR:

```
$ export KUBECONFIG=/etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-int.kubeconfig
$ oc get csr -o name | xargs oc adm certificate approve
$ exit
```

Make sure you logout from the master1. After renewing the certificate, the API server should start automatically.

The other masters should now add their CSR to the available master, which you can approve with a cluster-admin
user and the script `issueCertificates.sh`.
