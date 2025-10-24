output "name" {
  description = "The name of the VM"
  value       = proxmox_vm_qemu.this.name
}

output "vmid" {
  description = "The VMID of the VM"
  value       = proxmox_vm_qemu.this.vmid
}

output "node" {
  description = "The Proxmox node where the VM is running"
  value       = proxmox_vm_qemu.this.target_node
}

output "ip" {
  description = "The IP address assigned to the VM via cloud-init"
  value       = var.ip
}
