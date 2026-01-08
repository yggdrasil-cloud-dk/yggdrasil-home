#!/bin/bash

set -xe


lxc image list -f csv | grep -q ubuntu-noble-generic || {

cd $(dirname $0)

rm -f noble-server-cloudimg-amd64.img*
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

cat > metadata.yaml <<EOF
architecture: x86_64
creation_date: $(date +%Y%m%d)
properties:
  description: Ubuntu noble (generic)
  os: Ubuntu
  release: noble 24.04
EOF

rm -f metadata.tar.gz
tar -cvzf metadata.tar.gz metadata.yaml

lxc image import metadata.tar.gz noble-server-cloudimg-amd64.img --alias ubuntu-noble-generic

rm noble-server-cloudimg-amd64.img
rm metadata.tar.gz metadata.yaml

}
