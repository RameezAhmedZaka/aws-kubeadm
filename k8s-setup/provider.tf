provider "aws" {
  region = var.aws_region
  profile = var.profile
}

terraform {
  required_version = ">= 0.13.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}


# Only one data block
data "aws_ssm_parameter" "kubeconfig" {
  name = "/k8s/kubeconfig"
  depends_on	  = [module.manager.fetch_kubeconfig_id]

}

locals {
  kubeconfig = yamldecode(data.aws_ssm_parameter.kubeconfig.value)
  cluster    = local.kubeconfig.clusters[0].cluster
  user       = local.kubeconfig.users[0].user
}

provider "kubectl" {
  host                   = local.cluster.server
  cluster_ca_certificate = base64decode(local.cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.user["client-certificate-data"])
  client_key             = base64decode(local.user["client-key-data"])
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster.server
    cluster_ca_certificate = base64decode(local.cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.user["client-certificate-data"])
    client_key             = base64decode(local.user["client-key-data"])
    load_config_file       = false
  }
}

provider "kubernetes" {
  host                   = local.cluster.server
  cluster_ca_certificate = base64decode(local.cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.user["client-certificate-data"])
  client_key             = base64decode(local.user["client-key-data"])
  load_config_file       = false
}

