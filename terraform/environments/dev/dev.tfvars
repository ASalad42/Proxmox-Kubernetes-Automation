pm_api_url          = "https://ip:8006/api2/json"
pm_user             = "terra@pam"
pm_api_token_id     = "terra@pam!terra"
pm_api_token_secret = "supersecretapitoken"
pm_tls_insecure     = true

node                = "pve-home"
clone_from_template = "ubuntu-cloudinit"
ssh_public_key_path = "~/.ssh/terra.pub"
ci_user             = "ubuntu"
ci_password         = "supersecretpassword"
vm_cidr             = 24
vm_gateway          = "ip"

# Master Node
master = {
  name      = "k8s-master-1"
  vmid      = 105
  ip        = "ip"
  cores     = 2
  sockets   = 1
  memory_mb = 4096
}

# Worker Nodes
workers = {
  worker1 = {
    name      = "k8s-worker-1"
    vmid      = 110
    ip        = "ip"
    cores     = 1
    sockets   = 1
    memory_mb = 4096
  }
  worker2 = {
    name      = "k8s-worker-2"
    vmid      = 111
    ip        = "ip"
    cores     = 1
    sockets   = 1
    memory_mb = 4096
  }

  worker3 = {
    name      = "minIO-storage"
    vmid      = 112
    ip        = "ip"
    cores     = 1
    sockets   = 1
    memory_mb = 4096
  }
}

