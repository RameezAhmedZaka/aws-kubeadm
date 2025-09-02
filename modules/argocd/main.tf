terraform {
  required_version = ">= 0.13.6"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}
# ----------------------------
# Install ArgoCD via Helm
# ----------------------------
resource "helm_release" "argocd" {
  repository       = "https://argoproj.github.io/argo-helm"
  name             = "argocd"
  chart            = "argo-cd"
  version          = "5.24.1"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 300
  skip_crds        = true
  force_update     = true
  wait             = true
  recreate_pods    = true
  replace          = true


  values = [
    <<EOF
server:
  service:
    type: NodePort
EOF
  ]
}

# ----------------------------
# Docker Hub Secret (from SSM Parameter Store)
# ----------------------------
data "aws_ssm_parameter" "dockerhub" {
  name            = "/credentials/dockerhub"
  with_decryption = true
}

resource "kubectl_manifest" "dockerhub_secret" {
  depends_on = [helm_release.argocd]


  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-secret
  namespace: argocd
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${base64encode(data.aws_ssm_parameter.dockerhub.value)}
YAML
}

# ----------------------------
# GitHub Secret (from SSM Parameter Store)
# ----------------------------
data "aws_ssm_parameter" "github" {
  name            = "/credentials/github"
  with_decryption = true
}

locals {
  github = jsondecode(data.aws_ssm_parameter.github.value)
}

resource "kubectl_manifest" "github_secret" {
  depends_on = [helm_release.argocd]


  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: github-secret
  namespace: argocd
type: kubernetes.io/basic-auth
stringData:
  username: ${local.github.username}
  password: ${local.github.token}
YAML
}

resource "kubectl_manifest" "argocd_repo" {
  depends_on = [
    helm_release.argocd,
    kubectl_manifest.github_secret
  ]

  yaml_body = file("${path.module}/argocd_repo.yaml")
}

# ----------------------------
# Deploy ArgoCD Application
# ----------------------------
resource "kubectl_manifest" "argocd_app" {
  depends_on = [
    helm_release.argocd,
    kubectl_manifest.dockerhub_secret,
    kubectl_manifest.github_secret,
    kubectl_manifest.argocd_repo
  ]
  


  yaml_body = file("${path.module}/argocd_app.yaml")
}
