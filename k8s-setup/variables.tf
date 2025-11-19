variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "profile" {
  description = "Profile"
  type        = string
}
# variable "vpc" {
#   description = "VPC configuration"
#   type = object({
#     vpc_cidr_block              = string
#     vpc_name                    = string
#     internet_gateway            = string
#     public_subnet_cidr          = list(string)
#     private_subnet_cidr         = list(string)
#     public_availability_zones   = list(string)
#     private_availability_zones  = list(string)
#     public_subnet_name          = list(string)
#     private_subnet_name         = list(string)
#     route_destination           = string
#     nat_gateway                 = string
#     route_table_public          = string
#     route_table_private         = string
#     cidr_block                  = string
#     eip_name                    = string
#   })
# }

variable "existing_vpc_name" {
  description = "Name of the already existing VPC to use"
  type        = string
}


variable "node" {
  description = "Kubernetes node configuration"
  type = object({
    ami_id                   = string
    key_name                 = string
    instance_type_master     = string
    instance_type_worker     = string
    allowed_ip               = string
    sg_name                  = string
    sg_description           = string
    inbound_ports            = list(number)
    egress_cidr_block        = string
    master_node_name         = string
    master_node_role         = string
    master_node_cluster      = string
    ingress_cidr_block       = string
    worker_node_cluster      = string
    worker_node_role         = string
    worker_node_name         = string
    document_type            = string
  })
}

variable "iam" {
  description = "IAM configuration"
  type = object({
    manager_role_name        = string
    node_role_name           = string
    manager_profile_name     = string
    node_profile_name        = string
  })
}

variable "manager" {
  description = "Bastion host configuration"
  type = object({
    ami_id                 = string
    manager_name           = string
    manager_role           = string
    manager_cluster        = string
    manager_sg_name        = string
    manager_instance_type  = string
    user_data_file         = string
    subnet_index           = number
  })
}


