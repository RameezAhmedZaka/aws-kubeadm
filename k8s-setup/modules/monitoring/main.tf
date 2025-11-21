resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  force_update     = true
  wait             = false
  recreate_pods    = true
  replace          = true

  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"

  set = [

    # CRITICAL: Allow ServiceMonitors from ALL namespaces
    { name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues", value = "false" },
    { name = "prometheus.prometheusSpec.serviceMonitorNamespaceSelector",         value = "{}" },
    { name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues",    value = "false" },
    { name = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues",          value = "false" },

    # Disable components that cause TLS/connection issues in single-node clusters
    { name = "kubeEtcd.enabled",               value = "false" },
    { name = "kubeScheduler.enabled",          value = "false" },
    { name = "kubeControllerManager.enabled",  value = "false" },
    { name = "kubeProxy.enabled",              value = "false" },

    # Enable core components
    { name = "prometheusOperator.enabled",     value = "true" },
    { name = "alertmanager.enabled",           value = "true" },
    { name = "alertmanager.persistentVolume.enabled", value = "false" },

    # Exporters
    { name = "nodeExporter.enabled",           value = "true" },
    { name = "kubeStateMetrics.enabled",       value = "true" },
    { name = "coreDns.enabled",                value = "true" },
    { name = "kubelet.enabled",                value = "true" },

    # Grafana settings
    { name = "grafana.enabled",                value = "true" },
    { name = "grafana.adminPassword",          value = "admin123" },
    { name = "grafana.service.type",           value = "NodePort" },

    # Disable unnecessary components
    { name = "pushgateway.enabled",            value = "false" },
    { name = "thanosRuler.enabled",            value = "false" }
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

