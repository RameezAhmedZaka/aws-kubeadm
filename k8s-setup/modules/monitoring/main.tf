resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  replace          = true
  force_update     = true
  wait             = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  set = [
    { name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues", value = "false" },
    { name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues",    value = "false" },
    { name = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues",          value = "false" },

    { name = "kubeEtcd.enabled",              value = "false" },
    { name = "kubeScheduler.enabled",         value = "false" },
    { name = "kubeControllerManager.enabled", value = "false" },
    { name = "kubeProxy.enabled",             value = "false" },

    { name = "grafana.enabled",        value = "true" },
    { name = "grafana.adminPassword",  value = "admin123" },
    { name = "grafana.service.type",   value = "NodePort" },

    { name = "pushgateway.enabled", value = "false" },
    { name = "thanosRuler.enabled",  value = "false" }
  ]

  values = [
    <<-EOT
prometheus:
  prometheusSpec:
    serviceMonitorNamespaceSelector: {}
EOT
  ]
}




