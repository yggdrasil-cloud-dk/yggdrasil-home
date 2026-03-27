#!/bin/bash

set -e

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh

ID=$1

docker exec -it mariadb bash -c 'mariadb -p$(grep wsrep_sst_auth /etc/mysql/my.cnf | cut -d ':' -f 2) octavia -e "update load_balancer set provisioning_status=\"ERROR\" where id = \"'$ID'\";"'
