output "manager_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.manager.manager_public_ip
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = module.nodes.master_private_ip
}

output "worker_private_ips" {
  description = "Private IPs of the worker nodes"
  value       = module.nodes.worker_private_ips
}

output "master_instance_id" {
  value = module.nodes.master_instance_id
}

output "worker_instances_from_nodes" {
  value = module.nodes.worker_instances
}

