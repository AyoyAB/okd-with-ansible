SHELL := /usr/bin/env bash

.PHONY: all
all:
	$(error Please specify a make target)

.PHONY: env-check
env-check:
ifndef CLUSTER_NAME
	$(error Environment variable CLUSTER_NAME is not set)
endif

.PHONY: cluster
cluster: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v deploy-okd.yml | tee install-$$(date +%s).log

clean:
	rm -rf openshift-client openshift-files openshift-install
