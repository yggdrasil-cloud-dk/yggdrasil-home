resource "libvirt_volume" "vol_1" {
  name   = "ubuntu-core-1"
  source = "/root/yggdrasil_home/images/ubuntu-core/pc.img"

  provisioner "local-exec" {
    command = "truncate --size 300G /var/lib/libvirt/images/${self.name}"  # 300G volume
    interpreter = ["bash", "-c"]
  }
}

resource "libvirt_domain" "vm_1" { 
  name   = "hyper01"
  memory = "65536"
  vcpu   = 6
  firmware = "/usr/share/OVMF/OVMF_CODE.fd"

  network_interface {
    network_id     = libvirt_network.net_main.id
    hostname       = "hyper01"
    wait_for_lease = true
  }
  
  network_interface {
    network_id     = libvirt_network.net_prov.id
    hostname       = "hyper01"
    addresses      = ["10.0.80.11"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.vol_1.id
  }
  
  provisioner "local-exec" {
    command = var.prep_cmds
    interpreter = ["bash", "-c"]
    environment = {
      IP = self.network_interface[0].addresses[0]
      HOSTNAME = self.name
    }
  }

}