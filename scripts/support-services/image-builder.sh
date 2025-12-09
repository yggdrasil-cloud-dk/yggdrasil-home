#!/bin/bash

set -xe

# Networks & Subnets

create_network_and_subnet () {
	openstack network show $network_name || openstack network create $network_name
	openstack subnet show $subnet_name || openstack subnet create $subnet_name --dns-nameserver 8.8.8.8  --allocation-pool ${subnet_range} --network $network_name --subnet-range ${subnet_cidr}
}


network_name=image-builder_net
subnet_name=image-builder_subnet
subnet_cidr=172.16.1.0/24
subnet_range="start=172.16.1.101,end=172.16.1.254"
create_network_and_subnet

# Router

router=image-builder_router
openstack router show $router || openstack router create $router
openstack router set --external-gateway public1 $router
attached_subnet_ids=$(openstack router show $router -f value -c interfaces_info | sed "s/'/\"/g" | jq -r .[].subnet_id)
echo $attached_subnet_ids | grep -q $(openstack subnet show $subnet_name -f value -c id) || openstack router add subnet $router $subnet_name


# Security Groups

nsg=image-builder_nsg
openstack security group show $nsg || openstack security group create $nsg
openstack security group rule create $nsg --protocol tcp --dst-port 22 || true
openstack security group rule create $nsg --protocol icmp || true  # TODO: remove
openstack security group rule create $nsg --protocol tcp || true  # TODO: remove
openstack security group rule create $nsg --protocol udp || true  # TODO: remove


# Volume
volume_name=image-builder_vol
openstack volume show $volume_name || openstack volume create $volume_name --size 100 

# User-data

cat > /tmp/user_data.sh <<'EOF'
#!/bin/bash

set -x

# enable password ssh
sed 's/.*PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d/*
systemctl restart sshd

# change password
echo "ubuntu:ubuntu" | chpasswd

# virt-manager install
apt update
apt install -y virt-manager

# packer install
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository --yes "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update && apt install packer

mkdir -p /var/lib/libvirt/packer
cd /var/lib/libvirt/packer

# windows
git clone https://github.com/eaksel/packer-Win2022.git

# TODO: Get this working
# ubuntu
git clone https://github.com/rlaun/packer-ubuntu-22.04/

cd packer-Win2022

cat > win2022-gui.json <<'EOT'
{
    "variables": {
        "boot_wait": "5s",
        "disk_size": "40960",
        "iso_checksum": "4f1457c4fe14ce48c9b2324924f33ca4f0470475e6da851b39ccbf98f44e7852",
        "iso_url": "https://software-download.microsoft.com/download/sg/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso",
        "memsize": "2048",
        "numvcpus": "2",
        "vm_name": "Win2022_20324",
        "winrm_password" : "packer",
        "winrm_username" : "Administrator",
        "virtio_iso_path" : "virtio-win-0.1.229.iso"
    },
    "builders": [
        {
            "type": "qemu",
            "machine_type": "q35",
            "memory": "{{user `memsize`}}",
            "cpus": "{{user `numvcpus`}}",
            "vm_name": "{{user `vm_name`}}.qcow2",
            "iso_url": "{{user `iso_url`}}",
            "iso_checksum": "{{user `iso_checksum`}}",
            "headless": true,
            "boot_wait": "{{user `boot_wait`}}",
            "disk_size": "{{user `disk_size`}}",
            "disk_interface": "virtio-scsi",
            "disk_discard": "unmap",
            "disk_detect_zeroes": "unmap",
            "format": "qcow2",
            "communicator":"winrm",
            "winrm_username": "{{user `winrm_username`}}",
            "winrm_password": "{{user `winrm_password`}}",
            "winrm_use_ssl": true,
            "winrm_insecure": true,
            "winrm_timeout": "4h",
            "vnc_bind_address": "0.0.0.0",
            "qemuargs": [ [ "-cdrom", "{{user `virtio_iso_path`}}" ] ],
            "floppy_files": ["scripts/bios/gui/autounattend.xml"],
            "shutdown_command": "shutdown /s /t 5 /f /d p:4:1 /c \"Packer Shutdown\"",
            "shutdown_timeout": "30m"
        }
    ],
    "provisioners": [
        {
            "type": "powershell",
            "scripts": ["scripts/setup.ps1"]
        },
        {
            "type": "windows-restart",
            "restart_timeout": "180m"
        },
        {
            "type": "powershell",
            "scripts": ["scripts/win-update.ps1"]
        },
        {
            "type": "windows-restart",
            "restart_timeout": "180m"
        },
        {
            "type": "powershell",
            "scripts": ["scripts/win-update.ps1"]
        },
        {
            "type": "windows-restart",
            "restart_timeout": "180m"
        },
        {
            "type": "powershell",
            "scripts": ["scripts/custom.ps1"]
        },
        {
            "type": "powershell",
            "scripts": ["scripts/cleanup.ps1"],
            "pause_before": "1m"
        },
        {
            "type": "powershell",
            "inline": ["Get-ChildItem \"C:\\Windows\\Temp\\*\" -Recurse -Force -Verbose -ErrorAction SilentlyContinue | Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue"]
        }
    ]
}
EOT

cat > scripts/custom.ps1<<'EOT'
# Qemu agent
$url = "https://salt-fileserver.servercontrol.com.au/files/virtio/qemu-ga-x86_64.msi"
$dest = "$env:USERPROFILE\Downloads\qemu-ga-x86_64.msi"
Invoke-WebRequest -Uri $url -OutFile $dest 
Start-Process msiexec.exe -Wait -ArgumentList "/i $dest /qn /l*v log.txt /norestart"


# Cloudbase init
$url = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$dest = "$env:USERPROFILE\Downloads\CloudbaseInitSetup_Stable_x64.msi"
Invoke-WebRequest -Uri $url -OutFile $dest
Start-Process msiexec.exe -Wait -ArgumentList "/i $dest /qn /l*v log.txt /norestart RUNSYSPREP=0"


# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0

# Allow RDP through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOT

cat > ./scripts/cleanup.ps1 <<'EOT'
Function Cleanup {

    Clear-Host

    ## Stops the windows update service.
    Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue

    ## Deletes the contents of windows software distribution.
    Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue | Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue

    ## Delets all files and folders in user's Temp folder.
    Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue

    ## Remove all files and folders in user's Temporary Internet Files.
    Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

}

Cleanup
EOT

# plugin config
cat > template.pkr.hcl <<EOT
packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}
EOT


# download virtio iso
wget -q https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.229-1/virtio-win-0.1.229.iso

export HOME=/root

packer init .

PACKER_LOG=1 packer build -only=qemu win2022-gui.json #Windows Server 2022 w/ GUI

EOF

# VM and Floating IP

vm_name=image-builder
openstack server show $vm_name || openstack server create \
    --image jammy-server-cloudimg-amd64 \
    --flavor m1.large \
    --network $network_name \
    --security-group $nsg \
    --user-data /tmp/user_data.sh \
    $vm_name

fip=$(openstack floating ip list -f value | grep $(openstack port list --server $vm_name -f value -c id) | awk '{print $2}')
if [[ -z $fip ]]; then
  fip=$(openstack floating ip list -f value | grep "None None" | head -n 1 | awk '{print $2}')
  if [[ -z $fip ]]; then
    fip=$(openstack floating ip create public1 -f value -c floating_ip_address)
  fi
  openstack server add floating ip $vm_name $fip
fi

while ! [[ $(openstack server show $vm_name -f value -c status) == ACTIVE ]]; do sleep 5; done

openstack volume show $volume_name -f value -c status | grep -q available && \
openstack server add volume $vm_name $volume_name

ssh-keygen -f "/root/.ssh/known_hosts" -R $fip

ssh_cmd="sshpass -p ubuntu ssh -o StrictHostKeyChecking=no ubuntu@$fip"
while ! $ssh_cmd 'echo hi'; do sleep 10; echo "waiting for ssh.."; done
while ! $ssh_cmd 'ls -d /var/lib/libvirt/packer/packer-Win2022'; do echo "==> Packer repo not cloned yet.. waiting"; sleep 120; done
echo "==> Packer repo exists"
while ! $ssh_cmd 'sudo pstree | grep -q qemu-system'; do echo "==> VM not started yet.. waiting"; sleep 120; done
echo "==> VM exists"
$ssh_cmd 'echo "==> Ports available:"; sudo ss -lnp4 | grep qemu-system'
while $ssh_cmd 'sudo pstree | grep -q qemu-system'; do echo "==> VM still running.. waiting"; sleep 300; done
echo "==> VM is now off!"
echo "====== COMPLETE ======"
echo "QCOW image should now be ready!"

