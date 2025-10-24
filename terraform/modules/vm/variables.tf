variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "vmid" {
  description = "VM ID in Proxmox"
  type        = number
}

variable "node" {
  description = "Proxmox node where VMs should be created"
  type        = string
}

variable "ip" {
  description = "IP address of the VM"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
}

variable "memory_mb" {
  description = "Amount of memory (in MB)"
  type        = number
}

variable "vm_gateway" {
  description = "Default gateway for the VM"
  type        = string
}

variable "vm_cidr" {
  description = "CIDR subnet mask"
  type        = number
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
}

variable "ci_user" {
  description = "Default cloud-init username"
  type        = string
}

variable "ci_password" {
  description = "Default cloud-init password"
  type        = string
  sensitive   = true
}

variable "clone_from_template" {
  description = "Template VM to clone from"
  type        = string
}

variable "os_type" {
  description = "Operating system type (cloud-init friendly)"
  type        = string
  default     = "cloud-init"
}

variable "scsihw" {
  description = "SCSI controller type"
  type        = string
  default     = "virtio-scsi-pci"
}

variable "net_model" {
  description = "Network interface model"
  type        = string
  default     = "virtio"
}

variable "net_bridge" {
  description = "Bridge to attach network to"
  type        = string
  default     = "vmbr0"
}

variable "onboot" {
  description = "Start VM automatically on Proxmox boot"
  type        = bool
  default     = true
}
