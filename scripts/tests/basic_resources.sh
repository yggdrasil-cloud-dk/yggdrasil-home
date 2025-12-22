#!/bin/bash

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh

image_name=$(openstack image list -f value -c Name | grep trove)

openstack image set --private  \
    --tag trove --tag postgres --tag mysql $image_name


openstack keypair show --user trove testkey || openstack keypair create --public-key ~/.ssh/id_rsa.pub --user trove testkey

openstack datastore version show --datastore postgresql 12.18 || openstack datastore version create 12.18 postgresql postgresql "" \
    --image-tags trove,postgres \
    --active --default

suffix=$RANDOM
openstack database instance create postgresql_instance_$suffix \
    --flavor m1.medium \
    --size 5 \
    --nic net-id=$(openstack network show demo-net -f value -c id) \
    --databases test --users userA:password \
    --datastore postgresql --datastore-version 12.18 \
    --replica-count 1 \
    --is-public \
    --allowed-cidr 0.0.0.0/0


sleep 60

timeout_seconds=300
sleep_time=5
ready_status=ACTIVE
wip_status=BUILD
time=0
while true; do
  status=$(openstack database instance show postgresql_instance_$suffix -f value -c status)
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
  time=$(( $time + $sleep_time ))
  sleep $sleep_time
done
