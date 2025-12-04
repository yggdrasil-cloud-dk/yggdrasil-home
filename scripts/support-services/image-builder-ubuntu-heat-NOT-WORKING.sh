#!/bin/bash

set -xe

cd workspace

pip install git+https://opendev.org/openstack/diskimage-builder
ls tripleo-image-elements || (git clone https://opendev.org/openstack/tripleo-image-elements && \
  cd tripleo-image-elements && \
  git checkout HEAD^1)
ls heat-agents || git clone https://opendev.org/openstack/heat-agents
export ELEMENTS_PATH=tripleo-image-elements/elements:heat-agents/
disk-image-create vm \
  fedora selinux-permissive \
  os-collect-config \
  os-refresh-config \
  os-apply-config \
  heat-config \
  heat-config-ansible \
  heat-config-cfn-init \
  heat-config-docker-compose \
  heat-config-kubelet \
  heat-config-puppet \
  heat-config-salt \
  heat-config-script \
  -o fedora-software-config.qcow2
openstack image create --disk-format qcow2 --container-format bare fedora-software-config < \
  fedora-software-config.qcow2
