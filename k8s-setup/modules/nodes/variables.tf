variable "ami_id" {
  type        = string
  description = "AMI ID for all EC2 instances"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "instance_type_master" {
  type        = string
  description = "Instance type for master node"
}

variable "instance_type_worker" {
  type        = string
  description = "Instance type for worker nodes"
}

# Reused from data sources in root module
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs (from data source)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (from data source)"
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile for SSM access"
}

variable "sg_name" {
  description = "Security group name"
  type        = string
}

variable "sg_description" {
  description = "Security group description"
  type        = string
}

variable "inbound_ports" {
  description = "List of allowed TCP ports"
  type        = list(number)
}

variable "egress_cidr_block" {
  description = "CIDR block for access (e.g. 0.0.0.0/0)"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "ingress_cidr_block" {
  type        = string
  description = "Ingress CIDR block for security group"
}

variable "master_node_name" {
  type        = string
}

variable "master_node_role" {
  type        = string
}

variable "master_node_cluster" {
  type        = string
}

variable "worker_node_name" {
  type        = string
}

variable "worker_node_role" {
  type        = string
}

variable "worker_node_cluster" {
  type        = string
}

variable "document_type" {
  type        = string
}
