SHELL := /usr/bin/env bash

OC_CLIENT_PATH = ./openshift-client/oc
KUBECTL_PATH = ./openshift-client/kubectl
KUBECONFIG ?= ./openshift-files/auth/kubeconfig

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

.PHONY: cluster-ask-pass
cluster-ask-pass: env-check
	ansible-playbook -i inventories/${CLUSTER_NAME} -v deploy-okd.yml --ask-become-pass | tee install-$$(date +%s).log

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
