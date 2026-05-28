# =============================================================================
# Cost Management Module
# Kubecost with team/namespace allocation and Infracost configuration.
# =============================================================================

locals {
  kubecost_namespace = "kubecost"
}

# ------------------------------------------------------------------------------
# Kubecost Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "kubecost" {
  count = var.enable_kubecost ? 1 : 0

  metadata {
    name = local.kubecost_namespace
  }
}

# ------------------------------------------------------------------------------
# Kubecost Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "kubecost" {
  count = var.enable_kubecost ? 1 : 0

  name       = "kubecost"
  namespace  = kubernetes_namespace.kubecost[0].metadata[0].name
  repository = "https://kubecost.github.io/cost-analyzer"
  chart      = "cost-analyzer"
  version    = "2.0.0"

  set {
    name  = "kubecostModel.etlDailyStoreDurationDays"
    value = "365"
  }

  set {
    name  = "kubecostModel.etlHourlyStoreDurationHours"
    value = "720"
  }

  set {
    name  = "prometheus.server.retention"
    value = "30d"
  }

  values = [
    <<-EOT
    kubecostProductConfigs:
      clusterName: ${var.cluster_name}
      currencyCode: "USD"
    EOT
  ]

  depends_on = [kubernetes_namespace.kubecost]
}

# ------------------------------------------------------------------------------
# Infracost Config
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "infracost" {
  count = var.infracost_enabled ? 1 : 0

  metadata {
    name      = "infracost-config"
    namespace = kubernetes_namespace.kubecost[0].metadata[0].name
  }

  data = {
    "infracost.yml" = <<-EOT
      version: "0.1"
      projects:
        - path: terraform/
          terraform_workspace: default
      EOT
  }

  depends_on = [kubernetes_namespace.kubecost]
}
