#!/bin/bash

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate
source etc/kolla/admin-openrc.sh

CONFIG_DIR=$(pwd)/etc/kolla

cloudkitty module list

cloudkitty module disable pyscripts
openstack rating module enable hashmap
cloudkitty module set priority hashmap 100

openstack role add rating --project admin --user cloudkitty

group_id=$(cloudkitty hashmap group create instance_uptime_flavor_id -f value -c "Group ID")
service_id=$(cloudkitty hashmap service create instance -f value -c "Service ID")
field_id=$(cloudkitty hashmap field create $service_id flavor_id -f value -c "Field ID")

flavor_id=$(openstack flavor show m1.tiny -f value -c id)

cloudkitty hashmap mapping create 0.01 \
 --field-id $field_id \
 --value $flavor_id \
 -g $group_id \
 -t flat


# test cloudkitty is working

#openstack rating report tenant list

#openstack rating dataframes get -p <proj_id>
#openstack rating summary get -t <proj_id>
#openstack rating total get -t <proj_id>
