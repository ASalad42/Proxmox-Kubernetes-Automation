terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

resource "proxmox_vm_qemu" "this" {
  name        = var.name
  vmid        = var.vmid
  target_node = var.node

  clone = var.clone_from_template

  memory = var.memory_mb
  scsihw = var.scsihw

  cpu {
    cores   = var.cores
    sockets = var.sockets
  }

  network {
    id     = 0
    model  = var.net_model
    bridge = var.net_bridge
  }

  disk {
    slot    = "scsi0"
    size    = "32G"
    type    = "disk"
    storage = "local-lvm"
  }
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  boot = "order=scsi0;ide2"
  bios = "ovmf"
  vga {
    type = "serial0"
  }

  serial {
    id   = 0
    type = "socket"
  }

  os_type    = var.os_type
  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file(var.ssh_public_key_path)

  ipconfig0 = "ip=${var.ip}/${var.vm_cidr},gw=${var.vm_gateway}"

  agent = 1

  onboot = var.onboot
}
