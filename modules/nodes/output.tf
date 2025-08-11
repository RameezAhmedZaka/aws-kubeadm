output "master_private_ip" {
  description = "Private IP of the master node"
  value       = aws_instance.master.private_ip
}

output "worker_private_ips" {
  description = "Private IPs of the worker nodes"
  value       = [for instance in aws_instance.workers : instance.private_ip]
}

output "master_instance_id" {
  value = aws_instance.master.id
}