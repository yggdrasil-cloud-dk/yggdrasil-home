#!/bin/bash

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh

fedora_image="$(openstack image list -f value -c Name | grep fedora-coreos)"

# should fail if this isn't true
test $(echo "$fedora_image" | wc -l) -eq 1

openstack image set --property os_distro=fedora-coreos $fedora_image

ls ~/.ssh/id_rsa.pub || ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""

openstack keypair show testkey || openstack keypair create --public-key ~/.ssh/id_rsa.pub testkey

sleep 3

suffix=${RANDOM}

openstack coe cluster template create k8s-cluster-template-$suffix \
    --public \
    --image $fedora_image \
    --keypair testkey \
    --external-network public1 \
    --dns-nameserver 8.8.8.8 \
    --flavor m1.medium \
    --master-flavor m1.small \
    --docker-volume-size 5 \
    --volume-driver cinder \
    --network-driver calico \
    --docker-storage-driver overlay2 \
    --coe kubernetes \
    --labels kube_tag=v1.28.9-rancher1,container_runtime=containerd,containerd_version=1.6.31,containerd_tarball_sha256=75afb9b9674ff509ae670ef3ab944ffcdece8ea9f7d92c42307693efa7b6109d,cloud_provider_tag=v1.27.3,cinder_csi_plugin_tag=v1.27.3,k8s_keystone_auth_tag=v1.27.3,magnum_auto_healer_tag=v1.27.3,octavia_ingress_controller_tag=v1.27.3,calico_tag=v3.26.4,min_node_count=1

openstack coe cluster create k8s-cluster-$suffix \
    --cluster-template k8s-cluster-template-$suffix \
    --node-count 1


sleep 300

set +x

timeout_seconds=900
sleep_time=10
ready_status=CREATE_COMPLETE
wip_status=CREATE_IN_PROGRESS
time=0
while true; do
  status=$(openstack coe cluster show k8s-cluster-$suffix -f value -c status)
  if [[ $time -gt $timeout_seconds ]]; then
    echo Timeout reached - exiting
    exit 1
  elif echo $status | grep -q $ready_status; then
    echo Now available
    break
  elif echo $status | grep -qv $wip_status ; then
    echo Unexpected status
    exit 1
  fi
  echo Magnum: Waiting for cluster...
  time=$(( $time + $sleep_time ))
  sleep $sleep_time
done
