

module "vpc" {
  source                     = "./modules/vpc"
  vpc_cidr_block             = var.vpc.vpc_cidr_block
  vpc_name                   = var.vpc.vpc_name
  internet_gateway           = var.vpc.internet_gateway
  public_subnet_cidr         = var.vpc.public_subnet_cidr
  private_subnet_cidr        = var.vpc.private_subnet_cidr
  public_availability_zones  = var.vpc.public_availability_zones
  private_availability_zones = var.vpc.private_availability_zones
  public_subnet_name         = var.vpc.public_subnet_name
  private_subnet_name        = var.vpc.private_subnet_name
  cidr_block                 = var.vpc.route_destination
  nat_gateway                = var.vpc.nat_gateway
  route_table_public         = var.vpc.route_table_public
  route_table_private        = var.vpc.route_table_private
  eip_name                   = var.vpc.eip_name
}

module "iam" {
  source               = "./modules/iam"
  manager_role_name    = var.iam.manager_role_name
  node_role_name       = var.iam.node_role_name
  manager_profile_name = var.iam.manager_profile_name
  node_profile_name    = var.iam.node_profile_name

  depends_on           = [module.vpc]
}

module "nodes" {
  source                = "./modules/nodes"
  ami_id                = var.node.ami_id
  key_name              = var.node.key_name
  instance_type_master  = var.node.instance_type_master
  instance_type_worker  = var.node.instance_type_worker
  private_subnet_ids    = module.vpc.private_subnet_ids
  vpc_id                = module.vpc.vpc_id
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

  depends_on            = [module.vpc]
}


module "manager" {
  source                = "./modules/manager"
  ami_id                = var.manager.ami_id
  instance_type         = var.manager.manager_instance_type
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_subnet_ids[var.manager.subnet_index]
  iam_instance_profile  = module.iam.manager_iam_instance_profile
  manager_cluster       = var.manager.manager_cluster
  manager_role          = var.manager.manager_role
  manager_name          = var.manager.manager_name
  manager_sg_name       = var.manager.manager_sg_name
  user_data_file        = var.manager.user_data_file
  master_private_ip     = module.nodes.master_private_ip
  master_instance_id    = module.nodes.master_instance_id
  worker_instance_id    = module.nodes.worker_instances
  # manager_name          = "manager"
  
  

}
