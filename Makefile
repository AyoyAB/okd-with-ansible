#!make

# Include default .env if file exists
ifneq (,$(wildcard .env))
	include .env
endif

# Include cluster-specific .env if file exists
ifdef CLUSTER_NAME
ifneq (,$(wildcard inventories/${CLUSTER_NAME}/.env))
	include inventories/${CLUSTER_NAME}/.env
endif
endif

SHELL := /usr/bin/env bash

OC_CLIENT_PATH = ./openshift-client/oc
KUBECTL_PATH = ./openshift-client/kubectl
KUBECONFIG ?= ./openshift-files/auth/kubeconfig

# Export all variables to all shells in all targets
export

#
#
#

.PHONY: all
all:
	$(error Please specify a make target)

.PHONY: requirements
requirements:
	@python3 --version | grep --quiet "Python 3." || (echo "Please install Python 3 before running make!"; exit 1)
	@which jq > /dev/null || (echo "Please install jq before running make!"; exit 1)

.PHONY: local-pip-config
local-pip-config:
ifdef PIP_INDEXURL
	pip3 config set global.index-url "${PIP_INDEXURL}"
endif
ifdef PIP_CERT
	pip3 config set global.cert "${PIP_CERT}"
endif

.PHONY: dependencies
dependencies: requirements
	pip install -r requirements.txt
	ansible-galaxy install -r requirements.yml

.PHONY: local-dependencies
local-dependencies: local-pip-config dependencies

#
#
#

.PHONY: env-check
env-check:
ifndef CLUSTER_NAME
	$(error Environment variable CLUSTER_NAME is not set)
endif

#
# Lint
#

.PHONY: lint
lint: ansible-lint yaml-lint

.PHONY: ansible-lint
ansible-lint:
	ansible-lint

.PHONY: yaml-lint
yaml-lint:
	yamllint .

#
# Test (Molecule)
#

.PHONY: molecule-test
molecule-test:
	molecule test --all

#
# Local
#

.PHONY: local-tools
local-tools: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v install-local-tools.yml

.PHONY: local-files
local-files: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v create-local-files.yml

#
# Cluster
#

.PHONY: cluster
cluster: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v deploy-okd.yml 2>&1 | tee install-$$(date +%s).log

.PHONY: cluster-ask-pass
cluster-ask-pass: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v deploy-okd.yml --ask-become-pass 2>&1 | tee install-$$(date +%s).log

.PHONY: cluster-masters
cluster-masters: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v deploy-okd.yml --extra-vars="use_control_plane_nodes_for_compute=true"

.PHONY: cluster-config
cluster-config: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v configure-cluster.yml

#
# Load Balancer (lbs)
#

.PHONY: lbs
lbs: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v create-lbs.yml

.PHONY: lbs-config-ignition-files
lbs-config-ignition-files: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v configure-lbs-ignition-files.yml

.PHONY: lbs-config-bootstrap-enabled
lbs-config-bootstrap-enabled: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v configure-lbs-bootstrap-enabled.yml

.PHONY: lbs-config-bootstrap-disabled
lbs-config-bootstrap-disabled: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v configure-lbs-bootstrap-disabled.yml

#
# Clean
#

.PHONY: clean
clean:
	rm -rf openshift-client openshift-files openshift-install

#
#
#

.PHONY: login-check
login-check:
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} cluster-info 1> /dev/null || exit 1

#
# Assert
#

# Check and assert a good cluster state
.PHONY: assert-healthy-cluster
assert-healthy-cluster: login-check assert-healthy-openshift-pods assert-healthy-app-pods

# Check that all OpenShift PODs are in a good state
.PHONY: assert-healthy-openshift-pods
assert-healthy-openshift-pods:
	@echo -e "\nAssert that no OpenShift PODs are in bad state"
	@! ${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get pod --no-headers -A | grep ^openshift | grep -v -e Running -e Completed -e ContainerCreating
	@echo OK

# Check that all non OpenShift PODs are in a good state
.PHONY: assert-healthy-app-pods
assert-healthy-app-pods:
	@echo -e "\nAssert that no Application PODs are in bad state"
	@! ${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get pod --no-headers -A | grep -v ^openshift | grep -v -e Running -e Completed -e ContainerCreating
	@echo OK

#
# Status
#

# Display important cluster information
.PHONY: get-cluster-status
get-cluster-status: login-check get-cluster-version get-etcd-status
	@echo -e "\n>>> Cluster operators"
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get clusteroperators.config.openshift.io
	@echo -e "\n>>> Machine configuration pools"
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get mcp
	@echo -e "\n>>> Nodes"
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get node
	@echo -e "\n>>> PODs in bad state"
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get pod -A | grep -v -e Running -e Completed -e ContainerCreating

# Get cluster version and conditions
.PHONY: get-cluster-version
get-cluster-version: login-check
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} version
	@echo -e "\n>>> Cluster version status"
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get clusterversion version -o json | jq .status.conditions

# Get cluster version history
.PHONY: get-cluster-version-history
get-cluster-version-history: login-check
	@${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} get clusterversion version -o json | jq '.status.history | reverse'

# Display etcd info
.PHONY: get-etcd-status
get-etcd-status: login-check
	$(eval DOMAIN=$(shell ${OC_CLIENT_PATH} --kubeconfig ${KUBECONFIG} whoami --show-server | cut -d . -f 2- | cut -d : -f 1))
	@echo -e "\n>>> etcd endpoint status"
	@${KUBECTL_PATH} --kubeconfig ${KUBECONFIG} exec -it -n openshift-etcd etcd-master-1.${DOMAIN} -c etcd -- etcdctl endpoint status -w table
	@echo -e "\n>>> etcd endpoint health"
	@${KUBECTL_PATH} --kubeconfig ${KUBECONFIG} exec -it -n openshift-etcd etcd-master-1.${DOMAIN} -c etcd -- etcdctl endpoint health -w table
