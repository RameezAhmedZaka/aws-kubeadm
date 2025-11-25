terraform {
  required_version = ">= 0.13.6"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}
resource "helm_release" "argocd" {
  repository       = "https://argoproj.github.io/argo-helm"
  name             = "argocd"
  chart            = "argo-cd"
  version          = "5.24.1"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 600
  force_update     = true
  wait             = true
  recreate_pods    = true
  replace          = true

  set = [
    { name = "installCRDs", value = "true" },
    { name = "dex.enabled", value = "false" },
    { name = "server.service.type", value = "NodePort" }
  ]

  values = [
    <<-EOT
server:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"

controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"

repoServer:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"

applicationSet:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"

notifications:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"

redis:
  service:
    type: ClusterIP
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: "prometheus"
  exporter:
    enabled: true
    portName: metrics
EOT
  ]

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

# ----------------------------
# Deploy ArgoCD Application
# ---------------------------
resource "kubectl_manifest" "argocd_projects_apps" {
  depends_on = [
    helm_release.argocd,
    kubectl_manifest.github_secret
  ]

  yaml_body = file("${path.module}/argocd_projects_apps.yaml")
}
