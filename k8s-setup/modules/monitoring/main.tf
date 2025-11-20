
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  create_namespace = true
  timeout          = 300
  force_update     = true
  wait             = false
  recreate_pods    = true
  replace          = true
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  set = [
    {
      name  = "server.persistentVolume.enabled"
      value = "false"
    },
    {
      name  = "alertmanager.enabled"
      value = "true"
    },
    {
      name  = "alertmanager.persistentVolume.enabled"
      value = "false"
    },
    {
      name  = "pushgateway.enabled"
      value = "false"
    }
  ]
  depends_on = [helm_release.grafana]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = "monitoring"
  create_namespace = true
  wait             = false
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"

  set = [
    {
      name  = "persistence.enabled"
      value = "false"
    },
    {
      name  = "adminPassword"
      value = "admin"
    }
  ]
}

