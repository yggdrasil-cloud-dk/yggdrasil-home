#!/bin/bash

# Based on https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html

CONFIG_DIR=etc/kolla

# just sets `<key>: <value>` in globals.yml
function set_global_config () {
	config_key=$1
	config_value=$(echo "$2" | sed 's/\//\\\//g')  # escape any slash in value (e.g for a cidr)

	# handles when comments only in beginning of line
	if grep -q "#\? *$config_key:" $CONFIG_DIR/globals.yml; then
		sed -i "s/#\? *\($config_key:\).*/\1 $config_value/g" $CONFIG_DIR/globals.yml
	else
		sed -i "$ a $config_key: $config_value" $CONFIG_DIR/globals.yml
	fi
}

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

# generate passwords
PW_FILE=$CONFIG_DIR/passwords.yml
if [ ! -f "$PW_FILE" ]; then
	echo "$PW_FILE not found"
	exit 1
fi

kolla-genpwd -p $PW_FILE


# set global configs
set_global_config kolla_base_distro ubuntu
set_global_config kolla_install_type source

set_global_config network_interface $OPENSTACK_NETWORK_INTERFACE
set_global_config neutron_external_interface $OPENSTACK_NEUTRON_EXTERNAL_INTERFACE
set_global_config kolla_internal_vip_address $OPENSTACK_KOLLA_INTERNAL_VIP_ADDRESS

set_global_config glance_backend_ceph yes
set_global_config glance_backend_file no
set_global_config ceph_glance_keyring client.admin.keyring
set_global_config ceph_glance_user admin

set_global_config nova_backend_ceph yes
set_global_config ceph_nova_keyring client.admin.keyring
set_global_config ceph_nova_user admin

set_global_config enable_cinder yes
set_global_config cinder_backend_ceph yes
set_global_config ceph_cinder_keyring client.admin.keyring
set_global_config ceph_cinder_user admin

set_global_config enable_cinder_backup yes
set_global_config ceph_cinder_backup_keyring client.admin.keyring
set_global_config ceph_cinder_backup_user admin

set_global_config neutron_plugin_agent ovn
set_global_config neutron_ovn_dhcp_agent yes
set_global_config neutron_dns_domain "xyz.local."

set_global_config designate_dnssec_validation no
set_global_config designate_recursion yes
set_global_config designate_forwarders_addresses "\"$OPENSTACK_DESIGNATE_FORWARDERS_FIRST_ADDRESS; $OPENSTACK_DESIGNATE_FORWARDERS_SECOND_ADDRESS\""

set_global_config enable_aodh yes
set_global_config enable_barbican yes
set_global_config enable_ceilometer yes
set_global_config enable_central_logging yes  # takes lots of resources
#set_global_config enable_cloudkitty yes  # deployment broken - something about no cloudkitty database found
set_global_config enable_designate yes
set_global_config enable_freezer yes
set_global_config enable_gnocchi yes
set_global_config enable_grafana yes
set_global_config enable_kuryr yes
set_global_config enable_magnum yes
set_global_config enable_manila yes
set_global_config enable_manila_backend_generic yes
#set_global_config enable_masakari yes  # hacluster must be enabled - but this is an aio
set_global_config enable_mistral yes
#set_global_config enable_murano yes  # broken in 2023.2 for some reason
set_global_config enable_neutron_vpnaas yes
set_global_config enable_octavia yes
set_global_config enable_prometheus yes
set_global_config enable_redis yes
set_global_config enable_sahara yes
set_global_config enable_senlin yes
set_global_config enable_skyline yes
set_global_config enable_solum yes
set_global_config enable_tacker yes
set_global_config enable_trove yes
set_global_config enable_venus yes
#set_global_config enable_vitrage yes
set_global_config enable_watcher yes
#set_global_config enable_zun yes  # not supported in 2023.2

set_global_config docker_custom_config '{ "live-restore": true }'
#set_global_config docker_custom_config '{ "live-restore": true, "insecure-registries" : ["192.168.150.1:5000"] }'
#set_global_config skyline_console_image_full 192.168.150.1:5000/kolla/skyline-console:20.1.0

#set_global_config magnum_tag zed-ubuntu-jammy

set_global_config octavia_provider_drivers '"amphora:Amphora provider, ovn:OVN provider"'
set_global_config octavia_amp_network_cidr $OPENSTACK_AMPHORA_SUBNET_CIDR

set_global_config enable_ceph_rgw yes
set_global_config ceph_rgw_hosts "$OPENSTACK_CEPH_RGW_HOSTS"
set_global_config ceph_rgw_swift_account_in_url yes  # used to namespace per project with "AUTH_%(project_id)s"
set_global_config ceph_rgw_swift_compatibility no  # this is used to add "/swift/" in url, to distinguish from s3

set_global_config nova_console novnc

set_global_config openstack_service_workers "$OPENSTACK_WORKER_COUNT"
set_global_config openstack_service_rpc_workers "$OPENSTACK_WORKER_COUNT"

set_global_config disable_firewall no

for service in glance nova cinder/cinder-volume cinder/cinder-backup; do
	mkdir -p etc/kolla/config/$service/
	cp /etc/ceph/ceph.client.admin.keyring etc/kolla/config/$service/
	cat /etc/ceph/ceph.conf | sed 's/^\t//g' > etc/kolla/config/$service/ceph.conf
done

# magnum
mkdir -p etc/kolla/config/magnum/
cat >  etc/kolla/config/magnum/magnum-conductor.conf <<EOF
[trust]
cluster_user_trust = True
EOF

# trove
cat >  etc/kolla/config/trove.conf <<EOF
[DEFAULT]
max_accepted_volume_size = 50

[oslo_messaging_rabbit]
rabbit_quorum_queue = false
amqp_durable_queues = true
rabbit_ha_queues = true
EOF
mkdir -p etc/kolla/config/trove/
cat >  etc/kolla/config/trove/trove-taskmanager.conf <<EOF
[DEFAULT]
nova_keypair = testkey

[oslo_messaging_rabbit]
rabbit_quorum_queue = true
rabbit_ha_queues = false
EOF

# designate
mkdir -p etc/kolla/config/designate/
cat > etc/kolla/config/designate/named.conf <<EOF
#jinja2: trim_blocks: False
include "/etc/rndc.key";
options {
        listen-on port {{ designate_bind_port }} { {{ 'api' | kolla_address }}; };
        {% if api_interface != dns_interface %}
        listen-on port {{ designate_bind_port }} { {{ 'dns' | kolla_address }}; };
        {% endif %}
        directory       "/var/lib/named";
        allow-new-zones yes;
        dnssec-validation {{ designate_dnssec_validation }};
        auth-nxdomain no;
        request-ixfr no;
        recursion {{ designate_recursion }};
        allow-query-cache { any; };

        {% if designate_forwarders_addresses %}
        forwarders { {{ designate_forwarders_addresses }}; };
        {% endif %}
        minimal-responses yes;
        allow-notify { {% for host in groups['designate-worker'] %}{{ 'api' | kolla_address(host) }};{% endfor %} };
};

controls {
        inet {{ 'api' | kolla_address }} port {{ designate_rndc_port }} allow { {% for host in groups['designate-worker'] %}{{ 'api' | kolla_address(host) }}; {% endfor %} } keys { "rndc-key"; };
};
EOF

# neutron
mkdir -p etc/kolla/config/neutron/
cat > etc/kolla/config/neutron/dhcp_agent.ini <<EOF
[DEFAULT]
dnsmasq_dns_servers = {{ 'api' | kolla_address }}
EOF

# glance
config_dir=etc/kolla/config/glance
mkdir -p $config_dir
cat > $config_dir/glance-api.conf <<EOF
[DEFAULT]
show_image_direct_url = true
EOF

# nova
cat >  etc/kolla/config/nova.conf <<EOF
[DEFAULT]
cpu_allocation_ratio = 16.0
ram_allocation_ratio = 5.0
EOF
config_dir=etc/kolla/config/nova
mkdir -p $config_dir
cat > $config_dir/nova-compute.conf <<EOF
[glance]
enable_rbd_download = true
rbd_user = {{ ceph_glance_user }}
rbd_pool = {{ ceph_glance_pool_name }}
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_connect_timeout = 5

[libvirt]
cpu_mode = host-passthrough
EOF
