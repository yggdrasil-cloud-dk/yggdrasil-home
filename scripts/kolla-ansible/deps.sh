#!/bin/bash

# Based on documentation from https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html

set -xe

mkdir -p workspace
cd workspace

# update repos
apt update

# install python and deps
apt remove -y python3-docker
apt install -y python3-dev libffi-dev gcc libssl-dev python3-venv python3-pip libdbus-glib-1-dev #python3-openssl python3-docker

# Ensure that pip docker isn't installed system-wide
pip uninstall -y docker --break-system-packages

# refresh venv
rm -rf kolla-venv

# create venv
# NOTE: adding `--system-site-packages` because it needs python-apt module`
python3 -m venv --system-site-packages kolla-venv

# source path
source kolla-venv/bin/activate

# upgrade pip and install docker module
pip install -U pip docker

# install ansible
ANSIBLE_SKIP_CONFLICT_CHECK=1 pip install -U --ignore-installed 'ansible-core>=2.18,<2.19' 

# get python path in venv
#PYTHON_PATH=$(realpath -s kolla-venv/bin/python)

# configure ansible
#ln -sf /etc/ansible/ansible.cfg ./kolla-ansible/ansible
