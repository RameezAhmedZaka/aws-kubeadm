variable "vpc_id" {
  description = "The VPC ID where the bastion host will be deployed"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the bastion host instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID where the bastion host will be placed"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for SSM access"
  type        = string
}

variable "manager_sg_name" {
  description = "Name of the bastion security group"
  type        = string
  default     = "bastion-sg"
}

variable "manager_sg_egress_cidr" {
  description = "CIDR blocks for bastion SG egress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "user_data_file" {
  description = "Path to the user data script for bastion host"
  type        = string
}

variable "manager_name" {
  description = "Tag: Name for the bastion instance"
  type        = string
  
}

variable "manager_role" {
  description = "Tag: Role for the bastion instance"
  type        = string
 
}

variable "manager_cluster" {
  description = "Tag: Cluster name for the bastion instance"
  type        = string
 
}
