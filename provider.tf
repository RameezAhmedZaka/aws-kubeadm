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


data "aws_ssm_parameter" "kubeconfig" {
  depends_on      = [module.manager.fetch_kubeconfig_id] 
  name            = "/k8s/kubeconfig"
  with_decryption = true
}

# ----------------------------
# Parse kubeconfig YAML
# ----------------------------
locals {
  kubeconfig_yaml = yamldecode(data.aws_ssm_parameter.kubeconfig.value)

  cluster_info = local.kubeconfig_yaml["clusters"][0]["cluster"]
  user_info    = local.kubeconfig_yaml["users"][0]["user"]
}


provider "kubectl" {
  host                   = yamldecode(data.aws_ssm_parameter.kubeconfig.value)["clusters"][0]["cluster"]["server"]
  client_certificate     = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-key-data"])
  load_config_file       = false
  insecure               = true
}

# ----------------------------
# helm provider
# ----------------------------
provider "helm" {
  kubernetes = {
    host                   = yamldecode(data.aws_ssm_parameter.kubeconfig.value)["clusters"][0]["cluster"]["server"]
    client_certificate     = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-certificate-data"])
    client_key             = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-key-data"])
    load_config_file       = false
    insecure               = true
  }
}


provider "kubernetes" {
  host                   = "https://127.0.0.1:6443"
  client_certificate     = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(data.aws_ssm_parameter.kubeconfig.value)["users"][0]["user"]["client-key-data"])
  insecure               = true
}

