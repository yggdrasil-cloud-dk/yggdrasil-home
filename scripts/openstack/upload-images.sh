#!/bin/bash

set -xe

# source venv
cd workspace
source kolla-venv/bin/activate

CONFIG_DIR=$(pwd)/etc/kolla

# source admin rc
. $CONFIG_DIR/admin-openrc.sh


# TODO: Add windows image
# needs to be done manually for now due to EULA signature at
# https://cloudbase.it/windows-cloud-images/#download

# upload ubuntu image
image_urls=(
	https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
	https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/38.20230806.3.0/x86_64/fedora-coreos-38.20230806.3.0-openstack.x86_64.qcow2.xz
	https://tarballs.opendev.org/openstack/trove/images/trove-master-guest-ubuntu-jammy.qcow2
)

# After pipe_cmd, image should be of $image_format type
for image_url in ${image_urls[@]}; do
	pipe_cmd=cat
	# remove file extension
	image_name=$(echo $(basename $image_url) | grep -o ".*\." | head -c -2)
	image_format=qcow2
	if [[ "$image_url" == *".xz" ]]; then
		echo Image detected to be xz compressed. Will decompress.
		# removing file extension again - (probably .qcow2 or .img)
		image_name=$(echo $image_name | grep -o ".*\." | head -c -2)
		pipe_cmd="xz -d -"
	elif [[ "$image_url" == *".gz" ]]; then
		echo Image detected to be gz compressed. Will decompress.
		# removing file extension again - (probably .qcow2 or .img)
		image_name=$(echo $image_name | grep -o ".*\." | head -c -2)
		pipe_cmd="gunzip -cd"
	fi
	openstack image show $image_name || (
			echo ========== $image_name ===========
			(curl $image_url --output - || exit 1) | $pipe_cmd | cat - > $image_name.$image_format
			qemu-img convert $image_name.$image_format $image_name.raw
			if [[ "$image_url" == *jammy* ]]; then
				mkdir -p /mnt/openstack-image-mods
				losetup -fP $image_name.raw
				loop_dev=$(losetup | grep $image_name.raw | awk '{print $1}' | cut -d '/' -f 3)
				loop_part=$(lsblk -l | grep ${loop_dev}p | grep G | awk '{print $1}')
                	        (
					set -xe 
					mount /dev/$loop_part /mnt/openstack-image-mods
					chroot /mnt/openstack-image-mods bash -s <<-EOF
					set -x
					mkdir -p /run/systemd/resolve/
					echo nameserver 8.8.8.8 > /run/systemd/resolve/stub-resolv.conf
					# CHANGES START
					apt update
					DEBIAN_FRONTEND=noninteractive apt install -y \
						-o Dpkg::Options::="--force-confold" --force-yes \
						qemu-guest-agent python3-pip
					sed -i 's/disable_root: true/disable_root: false\nssh_pwauth: true\nchpasswd:\n  expire: false/'  /etc/cloud/cloud.cfg
					# CHANGES END
					rm -rf /run/systemd/resolve/
					EOF
					openstack image create --progress $image_name --file $image_name.raw
					rm -f $image_name*
				)
				umount /mnt/openstack-image-mods
				losetup -d /dev/$loop_dev
				rm -rf /mnt/openstack-image-mods
			else
				openstack image create --progress $image_name --file $image_name.raw
				rm -f $image_name*
			fi
		) &
done

wait

openstack image set --public \
  --os-distro ubuntu --property os_type=linux --property os_version=22.04 \
  --property os_admin_user=root  --property hw_qemu_guest_agent=yes \
  jammy-server-cloudimg-amd64

openstack image set --public \
  --os-distro fedora --property os_type=linux --property os_version=38 \
  --property os_admin_user=root \
  fedora-coreos-38.20230806.3.0-openstack.x86_64

pass=$(cat ~/hetzner-storagebox.pass)
if ! mount | grep -q /mnt/winshare; then
  mkdir -p /mnt/winshare
  mount.cifs -o user=u429780,pass=$pass //u429780.your-storagebox.de/backup /mnt/winshare/
fi

openstack image create --public \
  --property os_distro=windows --property os_type=windows --property os_version=s2022 \
  --property os_admin_user=Administrator \
  --file /mnt/winshare/Win2022_20241024.raw \
  --progress \
  Win2022_20241024
