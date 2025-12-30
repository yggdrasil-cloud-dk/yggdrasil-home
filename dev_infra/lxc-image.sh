#!/bin/bash

set -xe


lxc image list -f csv | grep -q ubuntu-jammy-generic || {

cd $(dirname $0)

rm -f jammy-server-cloudimg-amd64.img*
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

cat > metadata.yaml <<EOF
architecture: x86_64
creation_date: $(date +%Y%m%d)
properties:
  description: Ubuntu Jammy (generic)
  os: Ubuntu
  release: jammy 22.04
EOF

rm -f metadata.tar.gz
tar -cvzf metadata.tar.gz metadata.yaml

lxc image import metadata.tar.gz jammy-server-cloudimg-amd64.img --alias ubuntu-jammy-generic

rm jammy-server-cloudimg-amd64.img
rm metadata.tar.gz metadata.yaml

}
