terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# ----------------------------
# Security Group for Manager
# ----------------------------
resource "aws_security_group" "bastion_sg" {
  name   = var.manager_sg_name
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.manager_sg_egress_cidr
  }

  tags = {
    Name = var.manager_sg_name
  }
}

resource "aws_security_group_rule" "allow_laptop_to_master_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion_sg.id
  cidr_blocks       = ["154.192.59.95/32"]
}

resource "aws_security_group_rule" "allow_manager_to_master_api" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# ----------------------------
# Wait until master + workers are up
# ----------------------------
resource "null_resource" "wait_for_nodes" {
  triggers = {
    master  = var.master_instance_id
    workers = join(",", var.worker_instance_id)
  }
}

# ----------------------------
# Manager EC2 Instance
# ----------------------------
resource "aws_instance" "manager" {
  depends_on = [null_resource.wait_for_nodes]

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile

  user_data = file("${path.module}/user_data_ssm.sh")

  tags = {
    Name    = var.manager_name
    Role    = var.manager_role
    Cluster = var.manager_cluster
  }
}

# ----------------------------
# Wait + Fetch kubeconfig Locally
# ----------------------------
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [aws_instance.manager]

  provisioner "local-exec" {
    command = <<EOT
      echo "⌛ Waiting up to 10 minutes for kubeconfig on manager..."

      INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${var.manager_name}" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text)

      for i in {1..30}; do
        CMD_ID=$(aws ssm send-command \
          --targets "Key=instanceIds,Values=$INSTANCE_ID" \
          --document-name "AWS-RunShellScript" \
          --comment "Check kubeconfig" \
          --parameters 'commands=["test -f /etc/kubernetes/admin.conf && echo exists || echo missing"]' \
          --query "Command.CommandId" \
          --output text)

        sleep 10

        STATUS=$(aws ssm get-command-invocation \
          --command-id $CMD_ID \
          --instance-id $INSTANCE_ID \
          --query "StandardOutputContent" \
          --output text)

        if [ "$STATUS" = "exists" ]; then
          echo "✅ Kubeconfig ready, downloading..."

          CMD_ID=$(aws ssm send-command \
            --targets "Key=instanceIds,Values=$INSTANCE_ID" \
            --document-name "AWS-RunShellScript" \
            --comment "Fetch kubeconfig" \
            --parameters 'commands=["cat /etc/kubernetes/admin.conf"]' \
            --query "Command.CommandId" \
            --output text)

          sleep 10

          aws ssm get-command-invocation \
            --command-id $CMD_ID \
            --instance-id $INSTANCE_ID \
            --query "StandardOutputContent" \
            --output text > kubeconfig.yaml

          echo "✅ Kubeconfig saved to kubeconfig.yaml"
          break
        else
          echo "⌛ Not ready yet, retrying..."
          sleep 20
        fi
      done
    EOT
  }
}

# ----------------------------
# kubectl Provider (using local kubeconfig)
# ----------------------------
data "aws_ssm_parameter" "kubeconfig" {
  name           = "/k8s/kubeconfig"   # your SSM parameter name
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

# ----------------------------
# kubectl provider using SSM content
# ----------------------------
provider "kubectl" {
  host                   = local.cluster_info["server"]
  cluster_ca_certificate = base64decode(local.cluster_info["certificate-authority-data"])
  client_certificate     = base64decode(local.user_info["client-certificate-data"])
  client_key             = base64decode(local.user_info["client-key-data"])
  load_config_file       = false
}

# ----------------------------
# ArgoCD Namespace
# ----------------------------
resource "kubectl_manifest" "argocd_namespace" {

  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
YAML

  depends_on = [null_resource.fetch_kubeconfig]

  timeouts {
    create = "5m"
  }
}

# ----------------------------
# Download ArgoCD manifest dynamically
# ----------------------------
data "http" "argocd_manifest" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

# ----------------------------
# Split YAML into individual documents
# ----------------------------
locals {
  argocd_docs = [
    for doc in split("---", data.http.argocd_manifest.response_body) :
    trim(doc, " \t\n") if trim(doc, " \t\n") != ""
  ]
}

# ----------------------------
# Apply ArgoCD resources
# ----------------------------
resource "kubectl_manifest" "argocd_install" {

  for_each  = { for idx, doc in local.argocd_docs : idx => doc }
  yaml_body = each.value

  depends_on = [kubectl_manifest.argocd_namespace]

  timeouts {
    create = "5m"
  }
}



# ----------------------------
# Kubernetes Provider
# ----------------------------
# provider "kubernetes" {
#  config_path =  local_file.kubeconfig_file.kubeconfig_generated.yaml
# }


# # ----------------------------
# # Helm Provider
# # ----------------------------
# provider "helm" {
#   kubernetes = {
#     config_path = local_file.kubeconfig_file.filename
#     config_context = "kubernetes-admin@kubernetes"
#   }
# }
# # ----------------------------
# GitHub credentials from Secrets Manager
# ----------------------------
# data "aws_secretsmanager_secret_version" "github" {
#   secret_id = "github-credentials"
# }

# locals {
#   github_secret = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)
# }

# # ----------------------------
# # Kubernetes Secret for ArgoCD GitHub credentials
# # ----------------------------
# resource "kubernetes_secret" "argocd_github" {
#   depends_on = [local_file.kubeconfig_file]

#   metadata {
#     name      = "argocd-github-credentials"
#     namespace = "argocd"
#   }

#   data = {
#     username = base64encode(local.github_secret.username)
#     password = base64encode(local.github_secret.token)
#   }

#   type = "Opaque"
# }

# ----------------------------
# ArgoCD Helm Installation
# ----------------------------
# resource "helm_release" "argocd" {
#   # depends_on = [kubernetes_secret.argocd_github]

#   name             = "argocd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   namespace        = "argocd"
#   create_namespace = true
#   timeout          = 6000 
#   wait_for_jobs    = true
#   wait             = true
#   values = [file("${path.module}/argocd_values.yaml")]
#   lifecycle {
#   ignore_changes = all
# }
# }



# # ----------------------------
# # Security Group for Manager
# # ----------------------------
# resource "aws_security_group" "bastion_sg" {
#   name   = var.manager_sg_name
#   vpc_id = var.vpc_id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = var.manager_sg_egress_cidr
#   }

#   tags = {
#     Name = var.manager_sg_name
#   }
# }

# # ----------------------------
# # EC2 Manager Instance
# # ----------------------------
# resource "aws_instance" "manager" {

#   depends_on = [module.nodes] 

#   ami                         = var.ami_id
#   instance_type               = var.instance_type
#   subnet_id                   = var.private_subnet_id
#   vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
#   associate_public_ip_address = false
#   iam_instance_profile        = var.iam_instance_profile

#   user_data = file("${path.module}/user_data_ssm.sh") # Installs kubectl/helm and pushes kubeconfig to SSM

#   tags = {
#     Name    = var.manager_name
#     Role    = var.manager_role
#     Cluster = var.manager_cluster
#   }
# }

# # ----------------------------
# # Wait for kubeconfig to exist on manager (POSIX shell)
# # ----------------------------
# resource "null_resource" "wait_for_kubeconfig" {
#   depends_on = [aws_instance.manager]

#   provisioner "local-exec" {
#     command = <<EOT
# echo "⏳ Waiting for kubeconfig in Parameter Store..."
# i=1
# while [ $i -le 42 ]; do   # <-- 42 iterations = ~7 minutes
#   STATUS=$(aws ssm get-parameter --name "/k8s/kubeconfig" --region us-east-1 --query "Parameter.Value" --output text 2>/dev/null || echo "missing")
#   if [ "$STATUS" != "missing" ]; then
#     echo "✅ Kubeconfig found!"
#     echo "$STATUS" > "${path.module}/kubeconfig.yaml"

#     # Extract host, token, and ca for Terraform provider
#     KUBERNETES_HOST=$(kubectl --kubeconfig "${path.module}/kubeconfig.yaml" config view --minify -o jsonpath='{.clusters[0].cluster.server}')
#     KUBERNETES_CA=$(kubectl --kubeconfig "${path.module}/kubeconfig.yaml" config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
#     KUBERNETES_TOKEN=$(kubectl --kubeconfig "${path.module}/kubeconfig.yaml" config view --minify -o jsonpath='{.users[0].user.token}')

#     # Save these to local files for Terraform provider
#     echo "$KUBERNETES_HOST" > "${path.module}/kube_host.txt"
#     echo "$KUBERNETES_CA" > "${path.module}/kube_ca.txt"
#     echo "$KUBERNETES_TOKEN" > "${path.module}/kube_token.txt"

#     exit 0
#   fi
#   echo "Still waiting... ($i/42)"
#   sleep 10
#   i=$((i+1))
# done
# echo "❌ Timeout waiting for kubeconfig or API server not ready"
# exit 1
# EOT
#   }
# }


# # ----------------------------
# # Kubernetes & Helm providers (after kubeconfig exists)
# # ----------------------------
# provider "kubernetes" {
#   host                   = chomp(file("${path.module}/kube_host.txt"))
#   token                  = chomp(file("${path.module}/kube_token.txt"))
#   cluster_ca_certificate = base64decode(chomp(file("${path.module}/kube_ca.txt")))

# }

# provider "helm" {
#   kubernetes = {
#      host                   = chomp(file("${path.module}/kube_host.txt"))
#     token                  = chomp(file("${path.module}/kube_token.txt"))
#     cluster_ca_certificate = base64decode(chomp(file("${path.module}/kube_ca.txt")))
#   }
# }
# # ----------------------------
# # GitHub credentials from Secrets Manager
# # ----------------------------
# data "aws_secretsmanager_secret_version" "github" {
#   secret_id = "github-credentials"
# }

# locals {
#   github_secret = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)
# }

# resource "kubernetes_secret" "argocd_github" {
#   provider   = kubernetes.main
#   depends_on = [null_resource.wait_for_kubeconfig]

#   metadata {
#     name      = "argocd-github-credentials"
#     namespace = "argocd"
#   }

#   data = {
#     username = base64encode(local.github_secret.username)
#     password = base64encode(local.github_secret.token)
#   }

#   type = "Opaque"
# }

# # ----------------------------
# # ArgoCD Helm Installation
# # ----------------------------
# resource "helm_release" "argocd" {
#   provider   = helm.main
#   depends_on = [kubernetes_secret.argocd_github]

#   name             = "argocd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   namespace        = "argocd"
#   create_namespace = true

#   values = [file("${path.module}/argocd_values.yaml")]
# }
