# Prerequisites #

### On local Computer: ###

TIP: Set these vars:
```
HOSTNAME=
IP=
INITIALUSER=
```

1. Setup server from Hetzner GUI with password authentication

2. On local computer, ensure hyper01 (for OVH) and os02 (for Hetzner) is added: 
```
# hetzner
Host $HOSTNAME
    Hostname $IP
    User root
    ForwardAgent yes
EOF
```

3. Clone this repo
```
git clone git@github.com:mogindi/yggdrasil_home.git && cd yggdrasil_home
```

4. Run script to setup remote server
```
./setup_remote_os_server.sh $HOSTNAME $INITIALUSER
```

5. Copy secret files
```
scp -o StrictHostKeyChecking=no ~/brevo.rc $HOSTNAME:~/brevo.rc
scp -o StrictHostKeyChecking=no ~/hetzner-storagebox.pass $HOSTNAME:~/hetzner-storagebox.pass
```

6. Connect to remote server
```
ssh $HOSTNAME
```

### On Remote Server: ###

TIP: Set these vars:
```
git_user=
git_email=
```

6. Setup prerequisites
```
bash -s <<EOF
set -xe
apt update
apt install -y git make ansible bash-completion
ansible-galaxy collection install ansible.netcommon ansible.utils --force
echo "set -g history-limit 10000" > ~/.tmux.conf
echo "set paste" > ~/.vimrc

cat << 'EOT' > ~/.ssh/rc
#!/bin/bash
latest_ssh_auth_sock=\$(ls -dt /tmp/ssh-*/agent* | head -n 1)
ln -sf \$latest_ssh_auth_sock ~/.ssh/ssh_auth_sock
EOT
sed -i 's/.*PermitUserEnvironment.*/PermitUserEnvironment yes/g' /etc/ssh/sshd_config
systemctl restart ssh
echo 'SSH_AUTH_SOCK=/root/.ssh/ssh_auth_sock' > ~/.ssh/environment

cd ~
ls yggdrasil_home || GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone git@github.com:mogindi/yggdrasil_home.git
cd yggdrasil_home
git config --global user.email $git_email
git config --global user.name $git_user
git pull

EOF

bash ~/.ssh/rc
export SSH_AUTH_SOCK=/root/.ssh/ssh_auth_sock
cd yggdrasil_home
tmux
```

## LMA alerts and PagerDuty quick integration

This repository now includes additional Ceph/OpenStack alert rules and a quick Alertmanager PagerDuty integration path:

- Deploy the LMA bundle (rules + dashboards + Alertmanager config):
  ```bash
  make kollaansible-lma
  ```
- Deploy only Prometheus alert rules:
  ```bash
  make prometheus-alerts
  ```
- Render and apply Alertmanager config for PagerDuty:
  ```bash
  export PAGERDUTY_ROUTING_KEY=<pagerduty-integration-key>
  export PAGERDUTY_SEVERITY_MAP='critical|warning'
  make alertmanager-pagerduty
  ```

Notes:
- `PAGERDUTY_ROUTING_KEY` controls whether PagerDuty notifications are active.
- `PAGERDUTY_SEVERITY_MAP` is a regex used by Alertmanager route matchers.
