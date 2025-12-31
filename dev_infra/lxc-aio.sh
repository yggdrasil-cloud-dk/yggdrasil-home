#!/bin/bash

user_data=$(cat <<EOT
#!/bin/bash
echo ubuntu:ubuntu | chpasswd
rm /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh
EOT
)

lxc launch --vm --config limits.cpu=2 --config limits.memory=32GB --device root,size=100GiB \
  --config  cloud-init.user-data="$user_data"  \
  ubuntu-jammy-generic aio

while [[ -z $ip ]]; do
  sleep 5
  ip=$(lxc list -f csv | awk -F ',' '{print $3}' | awk '{print $1}')
done

cat > ~/.ssh/config <<EOF
# hetzner
host aio
    hostname $ip
    user root
    forwardagent yes
EOF

echo VM Ready!
