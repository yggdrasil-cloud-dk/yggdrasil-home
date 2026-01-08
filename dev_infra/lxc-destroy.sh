#!/bin/bash

set -xe

# containers/vms
lxc list -f csv | awk -F ',' '{print $1}' | xargs -I% lxc delete -f %

# images
lxc image list -f csv | awk -F ',' '{print $2}' | xargs -I% lxc image delete %

# profiles
lxc profile list -f csv | awk -F ',' '{print $1}' | grep -v default | xargs -I% lxc profile delete %
printf 'config: {}\ndevices: {}' | lxc profile edit default

# storage pools
lxc storage list -f csv | awk -F ',' '{print $1}' | xargs -I% lxc storage delete %

# remove snap
snap remove --purge lxd