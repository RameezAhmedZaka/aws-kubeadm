variable "manager_role_name" {
  type        = string
  description = "IAM Role name for bastion EC2"
}

variable "node_role_name" {
  type        = string
  description = "IAM Role name for node EC2"
}

variable "manager_profile_name" {
  type        = string
  description = "IAM Instance Profile name for bastion EC2"
}

variable "node_profile_name" {
  type        = string
  description = "IAM Instance Profile name for node EC2"
}