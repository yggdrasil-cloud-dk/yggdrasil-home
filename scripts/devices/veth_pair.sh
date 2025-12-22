#!/bin/bash

set -xe

sudo apt install -y net-tools

cat > /opt/veth_device.sh <<EOT
#!/bin/bash

ifconfig veth0 || bash -s <<EOF
set -xe
ip link add veth0 type veth peer name veth1
ip link set veth0 up
ip link set veth1 up
ip link set dev veth1 master br0

EOF
EOT

cat > /etc/systemd/system/network_veth_device.service <<EOF
[Unit]
Description=create veth device for openstack external gateway
After=network.target

[Service]
ExecStart=/bin/bash /opt/veth_device.sh
Type=oneshot

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

systemctl daemon-reload
systemctl restart network_veth_device.service
systemctl enable network_veth_device.service