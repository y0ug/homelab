variable "hosts" {
  type = map(object({
    vmid        = number
    ram         = number
    vcpu        = number
    macaddr     = optional(string)
    disk_sizes  = list(string)               # Allows multiple disks to be specified
    extra_disks = optional(list(string), []) # Optional field for additional hard drives
  }))
  default = {
    k8spv01 = {
      vmid       = 110
      ram        = 4096
      vcpu       = 8
      macaddr    = "B2:14:3E:A2:CB:3B"
      disk_sizes = ["64G"]
    }
    k8spv02 = {
      vmid       = 111
      ram        = 8192
      vcpu       = 8
      macaddr    = "5A:53:B1:49:11:68"
      disk_sizes = ["64G", "128G", "512G"]
    }
    k8spv04 = {
      vmid       = 114
      ram        = 8192
      vcpu       = 8
      macaddr    = "3A:E1:BF:69:AB:21"
      disk_sizes = ["64G", "128G"]
    }
  }
}

variable "target_node" {
  type    = string
  default = "pve002"
}

resource "proxmox_vm_qemu" "k8spv" {
  for_each = var.hosts

  name        = "${each.key}.mazenet.org"
  tags        = "terraform"
  desc        = null
  target_node = var.target_node
  vmid        = each.value.vmid

  sockets = 1
  cores   = 8
  vcpus   = each.value.vcpu
  memory  = each.value.ram
  balloon = 0

  cpu = "host"

  agent  = 1
  onboot = true

  qemu_os = "l26"

  hotplug = "network,disk,usb,memory,cpu"
  bios    = "seabios"
  boot    = "order=scsi0;ide2;net0"

  tablet = false

  numa   = true
  scsihw = "virtio-scsi-single"

  disk {
    type = "cdrom"
    slot = "ide2"
    iso  = "local:iso/preseed-debian-12.7.0-amd64-netinst.iso"
    # mandatory to avoid switching on re-apply
    backup = false
    format = "raw"
  }

  dynamic "disk" {
    for_each = { for i, x in each.value.disk_sizes : x => i }
    content {
      slot       = "scsi${disk.value}"
      size       = disk.key
      storage    = "local-nvme"
      format     = "raw"
      backup     = true
      discard    = true
      emulatessd = true
      iothread   = true
    }
  }


  network {
    bridge   = "vmbr0"
    firewall = false
    model    = "virtio"
    tag      = 101
    macaddr  = each.value.macaddr
  }
}
