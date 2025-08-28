# ----------------------------
# VPC Data Source
# ----------------------------
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-k8s-vpc"]
  }
}

# ----------------------------
# Subnets Data Source
# ----------------------------
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}
# ----------------------------
# IAM Module
# ----------------------------
module "iam" {
  source               = "./modules/iam"
  manager_role_name    = var.iam.manager_role_name
  node_role_name       = var.iam.node_role_name
  manager_profile_name = var.iam.manager_profile_name
  node_profile_name    = var.iam.node_profile_name
}

# ----------------------------
# Nodes Module
# ----------------------------
module "nodes" {
  source                = "./modules/nodes"
  ami_id                = var.node.ami_id
  key_name              = var.node.key_name
  instance_type_master  = var.node.instance_type_master
  instance_type_worker  = var.node.instance_type_worker
  private_subnet_ids    = data.aws_subnets.private.ids
  vpc_id                = data.aws_vpc.selected.id
  iam_instance_profile  = module.iam.node_iam_instance_profile
  sg_name               = var.node.sg_name
  sg_description        = var.node.sg_description
  inbound_ports         = var.node.inbound_ports
  egress_cidr_block     = var.node.egress_cidr_block
  master_node_name      = var.node.master_node_name
  master_node_role      = var.node.master_node_role
  master_node_cluster   = var.node.master_node_cluster
  ingress_cidr_block    = var.node.ingress_cidr_block
  worker_node_cluster   = var.node.worker_node_cluster
  worker_node_role      = var.node.worker_node_role
  worker_node_name      = var.node.worker_node_name
  document_type         = var.node.document_type
}

# ----------------------------
# Manager Module (Bastion)
# ----------------------------
module "manager" {
  source                = "./modules/manager"
  ami_id                = var.manager.ami_id
  instance_type         = var.manager.manager_instance_type
  vpc_id                = data.aws_vpc.selected.id
  private_subnet_id     = data.aws_subnets.private.ids[var.manager.subnet_index]
  iam_instance_profile  = module.iam.manager_iam_instance_profile
  manager_cluster       = var.manager.manager_cluster
  manager_role          = var.manager.manager_role
  manager_name          = var.manager.manager_name
  manager_sg_name       = var.manager.manager_sg_name
  user_data_file        = var.manager.user_data_file
  master_private_ip     = module.nodes.master_private_ip
  master_instance_id    = module.nodes.master_instance_id
  worker_instance_id    = module.nodes.worker_instances
}
