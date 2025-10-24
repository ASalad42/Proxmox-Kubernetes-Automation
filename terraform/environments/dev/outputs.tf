output "master_vm" {
  description = "Master node details"
  value = {
    name = module.master.name
    vmid = module.master.vmid
    node = module.master.node
    ip   = module.master.ip
  }
}

output "worker_vms" {
  description = "Worker node details"
  value = {
    for k, w in module.workers :
    k => {
      name = w.name
      vmid = w.vmid
      node = w.node
      ip   = w.ip
    }
  }
}
