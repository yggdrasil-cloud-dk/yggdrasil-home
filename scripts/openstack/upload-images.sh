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


modprobe nbd max_part=8

run_linux_cmd_in_qcow2_image () {

	image_path=$1
	cmd=$2
	mnt_args=$3

	mount_dir=/mnt/mod-image-$RANDOM
	nbd_dev="/dev/$(lsblk -d | grep nbd[0-9] | grep " 0B " | awk 'FNR == 1 {print $1}')"
	# seems set -e ignored inside the sub-shell, adding "|| exit 1 " in each line instead
	if ! [[ -z $cmd ]]; then
		(
			set -x
			mkdir -p $mount_dir
			qemu-nbd --connect=$nbd_dev $image_path
			sleep 1
			lsblk -d ${nbd_dev}p* -o NAME,SIZE | sort -k 2 -h | tail -n 1 | awk '{print $1}' | xargs -I% mount $mnt_args /dev/% $mount_dir  || exit 1 
			sleep 1
			chroot $mount_dir /bin/sh -c "mv /etc/resolv.conf /etc/resolv.conf.bk && echo nameserver 8.8.8.8 | tee /etc/resolv.conf" || exit 1
			echo ==== RUNNING CMD ====
			chroot $mount_dir /bin/sh -c "set -x; $cmd" || exit 1
			echo ==== END CMD ====
			chroot $mount_dir /bin/sh -c "mv /etc/resolv.conf.bk /etc/resolv.conf" || exit 1

			umount $mount_dir
			qemu-nbd --disconnect $nbd_dev
			sleep 2
			rm -rf $mount_dir
		) || \
		(
			set -x
			umount $mount_dir
			qemu-nbd --disconnect $nbd_dev
			sleep 2
			rm -rf $mount_dir
			exit 1
		)
	fi

}

create_openstack_linux_image() {
	image_url=$1
	image_name=$2
	cmd=$3
	extra_args=$4
	xz_decompress=$5
	mount_args=$6


	image_format=qcow2

	openstack image list -f value -c Name | grep $(echo $image_name | sed 's/\..*//g') || {
		echo ================= $image_name =================
		
		rm -f $image_name*
		if [[ -z $xz_decompress ]]; then
			wget -q $image_url -O $image_name.$image_format

		else
			wget -q $image_url -O $image_name.$image_format.xz
			xz -d $image_name.$image_format.xz
		fi
		run_linux_cmd_in_qcow2_image  $image_name.$image_format "$cmd" "$mount_args"
		qemu-img convert $image_name.$image_format $image_name.raw
		openstack image create $image_name --file $image_name.raw $extra_args
		rm -f $image_name*
	} 2>&1  # | tail -n 99999  # adding this to output all at once
}


date=$(date +%Y%m%d)

commands="apt update && DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Options::=--force-confdef -o DPkg::Options::=--force-confold install -y qemu-guest-agent"
create_openstack_linux_image https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
  ubuntu-jammy-22.04.$date.x86_64 \
  "$commands" \
  "--public --property os_distro=ubuntu --property os_type=linux --property os_version=22.04 --property os_admin_user=root --property hw_qemu_guest_agent=yes"

create_openstack_linux_image https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img  \
  ubuntu-noble-24.04.$date.x86_64 \
  "$commands" \
  "--public --property os_distro=ubuntu --property os_type=linux --property os_version=24.04 --property os_admin_user=root --property hw_qemu_guest_agent=yes"

# not running commands - no sh?
create_openstack_linux_image https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-20250106.0.x86_64.qcow2 \
  centos-stream-10.$date.x86_64 \
  "" \
  "--public --property os_distro=centos --property os_type=linux --property os_version=10 --property os_admin_user=root --property hw_qemu_guest_agent=no"  # TODO add qemu agent

create_openstack_linux_image https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2 \
  fedora-cloud-43.$date.x86_64 \
  "" \
  "--public --property os_distro=fedora --property os_type=linux --property os_version=43 --property os_admin_user=root --property hw_qemu_guest_agent=no"  # TODO add qemu agent

create_openstack_linux_image https://fastly.mirror.pkgbuild.com/images/v20260101.476437/Arch-Linux-x86_64-cloudimg.qcow2 \
  arch-linux-v20260101.20260101.x86_64 \
  "" \
  "--public --property os_distro=arch --property os_type=linux --property os_version=v20260101 --property os_admin_user=root --property hw_qemu_guest_agent=no"  # TODO add qemu agent

create_openstack_linux_image https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2 \
  debian-trixie-13.$date.x86_64 \
  "" \
  "--public --property os_distro=debian --property os_type=linux --property os_version=13 --property os_admin_user=root --property hw_qemu_guest_agent=no" # TODO add qemu agent

# can't even mount or run commands in image
create_openstack_linux_image https://download.freebsd.org/releases/VM-IMAGES/15.0-RELEASE/amd64/Latest/FreeBSD-15.0-RELEASE-amd64-ufs.qcow2.xz \
  freebsd-RELEASE-15.$date.x86_64 \
  "" \
  "--public --property os_distro=freebsd --property os_type=linux --property os_version=15 --property os_admin_user=root --property hw_qemu_guest_agent=no" \
  "xz_decompress"


set -xe

pass=$(cat ~/hetzner-storagebox.pass)
if ! mount | grep -q /mnt/winshare; then
  mkdir -p /mnt/winshare
  mount.cifs -o user=u429780,pass=$pass //u429780.your-storagebox.de/backup /mnt/winshare/
fi

file=/mnt/winshare/Win2022_20251209.raw
image_name=windows-server-2022.20251209.x86_64
openstack image show $image_name || openstack image create --public \
  --property os_distro=windows --property os_type=windows --property os_version=s2022 \
  --property os_admin_user=Administrator --property hw_qemu_guest_agent=yes \
  --file $file \
  --progress \
  $image_name

# Clean up left over images
rm *.qcow2* 

rmmod nbd