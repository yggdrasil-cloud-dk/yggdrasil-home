#!/bin/bash

set -xe

sudo apt install -y net-tools

cat > /etc/systemd/system/network_masquerade.service <<EOF
[Unit]
Description=Masquerade vlans when exiting primary interface
After=network.target

[Service]
Environment=DEFAULT_GW_INTERFACE=$(ip r | grep ^default | head -n 1 | grep -o "dev .*" | cut -d ' ' -f 2)
ExecStart=/bin/bash -c "iptables-save | grep -q \"\-A POSTROUTING -o \${DEFAULT_GW_INTERFACE} -j MASQUERADE\" || iptables -t nat -A POSTROUTING -o \${DEFAULT_GW_INTERFACE} -j MASQUERADE"
Type=oneshot

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

systemctl daemon-reload
systemctl restart network_masquerade.service
systemctl enable network_masquerade.service