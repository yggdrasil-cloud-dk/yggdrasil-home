#!/bin/bash

# Based on https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh

export EXT_NET_CIDR=$EXT_NET_CIDR
export EXT_NET_RANGE=$EXT_NET_RANGE
export EXT_NET_GATEWAY=$EXT_NET_GATEWAY

export KOLLA_CONFIG_PATH=$CONFIG_DIR
export ENABLE_EXT_NET=0

openstack network show public1  || \
	(openstack network create --share --external --provider-physical-network physnet1 --provider-network-type flat --mtu ${EXT_NET_MTU} public1 && \
	openstack subnet create --no-dhcp --allocation-pool ${EXT_NET_RANGE} --network public1 --subnet-range ${EXT_NET_CIDR} --gateway ${EXT_NET_GATEWAY} public1-subnet )

./kolla-ansible/tools/init-runonce

openstack router set --external-gateway public1 demo-router
