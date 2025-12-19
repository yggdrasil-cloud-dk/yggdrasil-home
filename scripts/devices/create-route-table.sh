
cat > /etc/systemd/system/network_create_route_table_$table.service <<EOF
[Unit]
Description=Network route table $table for $network_cidr
After=network.target

[Service]
ExecStart=/bin/bash -c "grep -q \"1 $table\" /etc/iproute2/rt_tables || ( echo \"1 $table\" | tee -a /etc/iproute2/rt_tables )"
ExecStart=/bin/bash -c "ip rule add from $network_cidr lookup $table"
ExecStart=/bin/bash -c "ip rule add to $network_cidr lookup $table"
ExecStart=/bin/bash -c "ip route add default via $gw dev $if table $table"
Type=oneshot

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

systemctl daemon-reload
systemctl restart network_create_route_table_$table.service
systemctl enable network_create_route_table_$table.service