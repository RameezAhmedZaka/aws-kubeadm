output "bastion_instance_id" {
  value = aws_instance.manager.id
}

output "manager_public_ip" {
  value = aws_instance.manager.public_ip
}
