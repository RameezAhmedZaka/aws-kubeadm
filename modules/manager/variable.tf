variable "vpc_id" {
  description = "Existing VPC ID (from data source in root module)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the bastion/manager host instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion/manager host"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for manager (from data source in root module)"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile for SSM access"
  type        = string
}

variable "manager_sg_name" {
  description = "Name of the manager/bastion security group"
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
  description = "Tag: Name for the manager instance"
  type        = string
}

variable "manager_role" {
  description = "Tag: Role for the manager instance"
  type        = string
}

variable "manager_cluster" {
  description = "Tag: Cluster name for the manager instance"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD app manifests"
  type        = string
  default     = "https://github.com/RameezAhmedZaka/kustomize-app.git"
}

variable "master_instance_id" {
  description = "ID of the master node (to wait for readiness)"
  type        = any
}

variable "worker_instance_id" {
  description = "List of worker node instance IDs (to wait for readiness)"
  type        = list(any)
}

variable "master_private_ip" {
  description = "Private IP address of master node"
  type        = string
}
