#!/bin/bash

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh

source ../scripts/openstack/image-utils.sh

image=trove-master-guest-ubuntu-noble

commands="sed -i \
-e '/LOG.info(f\"Creating database {database.name}\")/a\' \
-e '        database.collate = \"en_US.utf8\"' \
/opt/guest-agent-venv/lib/python3.12/site-packages/trove/guestagent/datastore/postgres/service.py"

create_openstack_linux_image https://tarballs.opendev.org/openstack/trove/images/$image.qcow2 \
  $image \
  "$commands" \
  "--property hw_rng_model='virtio'"

image_name=$image

openstack image set --private  \
    --tag trove --tag postgres --tag mysql $image_name

openstack keypair show --user trove testkey || openstack keypair create --public-key ~/.ssh/id_rsa.pub --user trove testkey

openstack datastore version show --datastore postgresql 17 || openstack datastore version create 17 postgresql postgresql "" \
    --image-tags trove,postgres \
    --active --default

openstack datastore version show --datastore mysql 8.4 || openstack datastore version create 8.4 mysql mysql "" \
    --image-tags trove,mysql \
    --active --default