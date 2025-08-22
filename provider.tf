terraform {
  required_version = ">= 0.13.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# provider "kubectl" {
#   alias                  = "module_provider"
#   host                   = local.cluster_info["server"]
#   cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
#   client_certificate     = base64decode(local.user_info["client-certificate-data"])
#   client_key             = base64decode(local.user_info["client-key-data"])
#   load_config_file       = false
# }






  # load_config_file = false 













# provider "kubectl" {
#   alias       = "module_provider"
#   config_path = "/root/.kube/config"  # Path used in user_data_ssm.sh
# }
# terraform {
#    required_version = ">= 0.13"
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 3.66.0"
#     }
#     # kubernetes = {
#     #   source  = "hashicorp/kubernetes"
#     #   version = ">= 2.7.1"
#     # }
#     # helm = {
#     #   source  = "hashicorp/helm"
#     #   version = ">= 2.4.1"
#     # }
#     kubectl = {
#       source  = "gavinbunney/kubectl"
#        version = ">= 1.14.0"

#   }

#     null = {
#       source  = "hashicorp/null"
#       version = ">= 3.2.0"
#     }
#     http = {
#       source  = "hashicorp/http"
#       version = ">= 3.5.0"
#     }
# }
# }