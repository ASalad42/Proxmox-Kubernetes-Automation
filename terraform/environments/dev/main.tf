terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_user             = var.pm_user
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

# Master Node
module "master" {
  source = "../../modules/vm"

  name      = var.master.name
  vmid      = var.master.vmid
  node      = var.node
  ip        = var.master.ip
  cores     = var.master.cores
  sockets   = var.master.sockets
  memory_mb = var.master.memory_mb

  clone_from_template = var.clone_from_template
  ci_user             = var.ci_user
  ci_password         = var.ci_password
  ssh_public_key_path = var.ssh_public_key_path
  os_type             = "cloud-init"
  scsihw              = "virtio-scsi-pci"
  net_model           = "virtio"
  net_bridge          = "vmbr0"
  vm_cidr             = var.vm_cidr
  vm_gateway          = var.vm_gateway
  onboot              = true
}

# Worker Nodes
module "workers" {
  source   = "../../modules/vm"
  for_each = var.workers

  name      = each.value.name
  vmid      = each.value.vmid
  node      = var.node
  ip        = each.value.ip
  cores     = each.value.cores
  sockets   = each.value.sockets
  memory_mb = each.value.memory_mb

  clone_from_template = var.clone_from_template
  ci_user             = var.ci_user
  ci_password         = var.ci_password
  ssh_public_key_path = var.ssh_public_key_path
  os_type             = "cloud-init"
  scsihw              = "virtio-scsi-pci"
  net_model           = "virtio"
  net_bridge          = "vmbr0"
  vm_cidr             = var.vm_cidr
  vm_gateway          = var.vm_gateway
  onboot              = true
}
