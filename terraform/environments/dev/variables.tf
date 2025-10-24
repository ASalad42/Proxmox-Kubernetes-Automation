variable "pm_api_url" {
  description = "Proxmox API URL (include /api2/json)"
  type        = string
  default     = "https://ip:8006/api2/json"
}

variable "pm_user" {
  description = "Proxmox user"
  type        = string
  default     = "terra@pam"
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Allow insecure TLS"
  type        = bool
  default     = true
}


variable "vm_gateway" {
  description = "Default gateway for the VMs"
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

variable "node" {
  description = "Proxmox node where VMs should be created"
  type        = string
}

# Master VM config
variable "master" {
  description = "Master VM configuration"
  type = object({
    name      = string
    vmid      = number
    ip        = string
    cores     = number
    sockets   = number
    memory_mb = number
  })
}

# Worker VMs config
variable "workers" {
  description = "Worker VM configurations"
  type = map(object({
    name      = string
    vmid      = number
    ip        = string
    cores     = number
    sockets   = number
    memory_mb = number
  }))
}