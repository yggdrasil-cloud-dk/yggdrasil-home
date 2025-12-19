SHELL:=/bin/bash

ENV = hetzner-vagrant-dev01
ARGS = 
TAGS = 

#########
# Setup #
#########

# TODO: run in ansible so it runs on all nodes
prepare-ansible:
	rm -rf /etc/ansible/
	mkdir -p /etc/ansible
	ln -sfr ansible/inventory/$(ENV) /etc/ansible/hosts
	ln -sfr ansible/ansible.cfg /etc/ansible/ansible.cfg

harden:
	ansible-playbook ansible/harden.yml $(ARGS)

vpn: 
	ansible-playbook ansible/vpn.yml $(ARGS)

devices-configure:
	ansible-playbook ansible/devices.yml $(ARGS)

checks:
	ansible-playbook ansible/checks.yml $(ARGS)

cephadm-deploy:
	ansible-playbook ansible/cephadm.yml $(ARGS)

# kolla-ansible #

kollaansible-images:
	ansible-playbook ansible/prepare_images.yml $(ARGS)

kollaansible-prepare:
	ansible-playbook ansible/kolla_ansible.yml $(ARGS)

kollaansible-create-certs:
	scripts/kolla-ansible/kolla-ansible.sh octavia-certificates

kollaansible-bootstrap:
	scripts/kolla-ansible/kolla-ansible.sh bootstrap-servers

kollaansible-prechecks:
	scripts/kolla-ansible/kolla-ansible.sh prechecks

kollaansible-deploy:
	scripts/kolla-ansible/kolla-ansible.sh deploy || scripts/kolla-ansible/kolla-ansible.sh deploy

kollaansible-upgrade:
	scripts/kolla-ansible/kolla-ansible.sh upgrade

kollaansible-postdeploy:
	scripts/kolla-ansible/kolla-ansible.sh post-deploy

kollaansible-lma:
	ansible-playbook ansible/lma.yml -v
	scripts/kolla-ansible/kolla-ansible.sh reconfigure -t prometheus

prometheus-alerts:
	scripts/lma/prometheus-alerts/copy-rules.sh
	scripts/kolla-ansible/kolla-ansible.sh reconfigure -t prometheus

# openstack #

openstack-client-install:
	ansible-playbook ansible/client.yml $(ARGS)

openstack-resources-init:
	ansible-playbook ansible/init_resources.yml $(ARGS)
	#scripts/openstack/init-resources.sh

openstack-images-upload:
	scripts/openstack/upload-images.sh

symlink-etc-kolla:
	ln -sfr workspace/etc/kolla/* /etc/kolla/

openstack-octavia:
	ansible-playbook ansible/openstack_initialize/octavia.yml $(ARGS)

openstack-rgw:
	ansible-playbook ansible/openstack_initialize/rgw.yml $(ARGS)

openstack-magnum:
	scripts/tests/magnum.sh

openstack-manila:
	scripts/tests/manila.sh

openstack-trove-postgres:
	scripts/tests/trove_postgres.sh

openstack-remove-test-resources:
	scripts/tests/remove-all.sh


###########
# Bundles #
###########

init: prepare-ansible

infra-up: harden vpn devices-configure checks cephadm-deploy 

kollaansible-up: kollaansible-images kollaansible-prepare kollaansible-create-certs kollaansible-bootstrap kollaansible-prechecks kollaansible-deploy kollaansible-lma

all-up: infra-up kollaansible-up

dev-up: vagrant-up all-up all-postdeploy

dev-down: vagrant-destroy

all-upgrade: kollaansible-upgrade

openstack-services:
	ls ~/.ssh/id_rsa.pub || ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
	$(MAKE) -j 5 -Oline openstack-octavia openstack-rgw openstack-magnum  openstack-manila openstack-trove-postgres
	$(MAKE) openstack-remove-test-resources

all-postdeploy: kollaansible-postdeploy openstack-client-install openstack-resources-init openstack-images-upload symlink-etc-kolla  openstack-services

########
# Util #
########

vagrant-install:
	cd vagrant && ./setup.sh

vagrant-up:
	cd vagrant && vagrant up

vagrant-destroy:
	cd vagrant && vagrant destroy -f

# print make vars. Use like this "make print-ENV" to print ENV 
print-%  : ; @echo $* = $($*)

# ping nodes
ping-nodes:
	scripts/ping-nodes.sh

# print ansible inventory vars
print-ansible-vars:
	ansible all -m debug -a "var=hostvars"
	
# missing tags that are used with "import_playbook" list nova
print-tags:
	@grep "^        tags:" workspace/kolla-ansible/ansible/site.yml | sed 's/        tags: //g; s/ }//g; s/,.*//g; s/\[//g' | xargs | sed 's/ /,/g' | tee /tmp/print-tags

kollaansible-tags-deploy: kollaansible-prepare
	scripts/kolla-ansible/kolla-ansible.sh deploy -t $(TAGS)

kollaansible-tags-upgrade: kollaansible-prepare
	scripts/kolla-ansible/kolla-ansible.sh upgrade -t $(TAGS)

# Set single tag
kollaansible-fromtag-deploy: kollaansible-prepare print-tags
	all_tags=$$(cat /tmp/print-tags) && \
	remaining_tags=$$(echo $$all_tags | grep -o $(TAGS).*) && \
	scripts/kolla-ansible/kolla-ansible.sh deploy -t $$remaining_tags

kollaansible-up-upgrade: kollaansible-images kollaansible-prepare kollaansible-prechecks kollaansible-upgrade kollaansible-lma

kollaansible-tags-reconfigure: kollaansible-prepare
	scripts/kolla-ansible/kolla-ansible.sh reconfigure -t $(TAGS) -v

kollaansible-reconfigure: kollaansible-prepare
	scripts/kolla-ansible/kolla-ansible.sh reconfigure -v

kollaansible-destroy:
	scripts/kolla-ansible/kolla-ansible.sh destroy --yes-i-really-really-mean-it
	@echo -e "-----\nPLEASE REBOOT NODES\n-----"; sleep 5

kollaansible-purge: kollaansible-destroy
	@rm -rf workspace

cephadm-destroy:
	ansible-playbook ansible/cephadm.yml -t destroy

devices-destroy:
	ansible-playbook ansible/devices.yml -t destroy

openstack-resources-destroy:
	scripts/openstack/destroy-resources.sh

clean: kollaansible-purge cephadm-destroy devices-destroy
