#!/bin/bash

set -x

#TODO: this shouldn't be here. It needs to be done once when settup up host

BACKEND_DEVICE=vdb
add_to_systemd_loop_unit_file=false
if (lsblk | grep -q $BACKEND_DEVICE) && (! mount | grep -q $BACKEND_DEVICE); then
	
	## format backend device
	mkfs.ext4 /dev/$BACKEND_DEVICE
	
	## mount backend device
	mount /dev/$BACKEND_DEVICE /mnt

	## add to fstab
	echo -e "/dev/vdb\t/mnt\text4\tdefaults\t0\t0" | tee -a /etc/fstab

	$add_to_systemd_loop_unit_file=true
fi

cat > /opt/loop-device.sh << EOF
#!/bin/bash

set -x

# change dir
cd /mnt

ls disk-0.img || truncate -s ${LOOP_DEVICE_SIZE_GB}G disk-0.img
ls disk-1.img || truncate -s ${LOOP_DEVICE_SIZE_GB}G disk-1.img
ls disk-2.img || truncate -s ${LOOP_DEVICE_SIZE_GB}G disk-2.img


# create image files
lsblk | grep -q loop100 || losetup /dev/loop100 disk-0.img
lsblk | grep -q loop101 || losetup /dev/loop101 disk-1.img
lsblk | grep -q loop102 || losetup /dev/loop102 disk-2.img

test \$(lvscan | grep "/dev/vg-0/lv-0\|/dev/vg-1/lv-1\|/dev/vg-2/lv-2" | wc -l) == 3 || (
	# create pvs
	pvcreate /dev/loop100
	pvcreate /dev/loop101
	pvcreate /dev/loop102

	# create vgs
	vgcreate vg-0 /dev/loop100
	vgcreate vg-1 /dev/loop101
	vgcreate vg-2 /dev/loop102

	# create lvms
	# note: lvms will be at path /dev/vg-X/lv-X
	lvcreate -n lv-0 -l 100%FREE vg-0
	lvcreate -n lv-1 -l 100%FREE vg-1
	lvcreate -n lv-2 -l 100%FREE vg-2
)
vgchange -ay
exit 0

EOF

systemd_loop_after=
$add_to_systemd_loop_unit_file && systemd_loop_after=mnt.mount

# make devices persistent
cat > /etc/systemd/system/storage_loop_device.service << EOF
[Unit]
After=$systemd_loop_after

[Service]
Type=oneshot
ExecStart=-/bin/bash /opt/loop-device.sh

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl restart storage_loop_device.service
systemctl enable storage_loop_device.service


exit 0
