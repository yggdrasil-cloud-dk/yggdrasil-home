#!/bin/bash

set -x

apt install -y openscap-scanner bzip2

release=$(lsb_release -cs)

zip_file=com.ubuntu.$release.usn.oval.xml.bz2
xml_file=com.ubuntu.$release.usn.oval.xml
htm_file=oval-$release.html

cd /tmp
rm -rf ${zip_file}*
wget https://security-metadata.canonical.com/oval/$zip_file
bzip2 -d $zip_file

oscap oval eval --report $htm_file $xml_file


