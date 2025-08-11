output "manager_iam_instance_profile" {
  value = aws_iam_instance_profile.manager_ssm_instance_profile.name
}

output "node_iam_instance_profile" {
  value = aws_iam_instance_profile.node_ssm_instance_profile.name
}