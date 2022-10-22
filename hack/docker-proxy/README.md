# Docker-proxy

The docker proxy is used to create a caching registry for docker.io and quai.io. There are different 
justifications for this.

Having a proxy for quay.io mimics the environment of a semi-disconnected environment. In theory
it should also be faster, depending on your Internet speed. In my case it wasn't, since I'm running
the registry proxy on a low-end QNAP NAS.

Having a proxy for docker.io relieves the cluster from having to use a pull secret for docker.io to
circumvent their request limit. Also, docker.io is a free service and we should not overuse their 
hospitality.

## Usage

1. Create the CA
   ```
   make ca
   ```

2. Start the caching registry
   ```
   make docker.io
   make quay.io
   ```

## Trust certificate in docker for Mac

According to the documentation, Docker for mac uses the system CA list, to which you can add the CA like this:

```
security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain openshift-files/ca.pem
```

However, it seems it also reads the CA from ~/.docker/certs.d/registry.okd4.example.com:5010/ca.pem and
the best way seems to copy the CA there.
