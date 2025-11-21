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
  skip_crds        = false
  force_update     = true
  wait             = true
  recreate_pods    = true
  replace          = true

  set = [

    { name = "installCRDs", value = "true" },

    # Metrics
    { name = "server.metrics.enabled", value = "true" },
    { name = "controller.metrics.enabled", value = "true" },
    { name = "repoServer.metrics.enabled", value = "true" },
    { name = "applicationSet.metrics.enabled", value = "true" },
    { name = "notifications.metrics.enabled", value = "true" },
    { name = "redis.metrics.enabled", value = "true" },

    # Prometheus integration
    { name = "prometheus.enabled", value = "true" },
    { name = "prometheus.serviceMonitor.enabled", value = "true" },
    { name = "prometheus.serviceMonitor.additionalLabels.release", value = "prometheus" },

    { name = "metrics.enabled", value = "true" },
    { name = "metrics.serviceMonitor.enabled", value = "true" },
    { name = "metrics.serviceMonitor.additionalLabels.release", value = "prometheus" },

    # Ports
    { name = "server.service.metricsPort", value = "8083" },
    { name = "controller.service.metricsPort", value = "8082" },
    { name = "repoServer.service.metricsPort", value = "8084" },
    { name = "applicationSet.service.metricsPort", value = "8080" },

    # Server
    { name = "server.service.type", value = "NodePort" },

    # Disable Dex
    { name = "dex.enabled", value = "false" }
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
