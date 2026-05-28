# =============================================================================
# Observability Module
# Prometheus + Grafana with MTTP dashboard and PagerDuty integration.
# =============================================================================

locals {
  monitoring_namespace = "monitoring"
}

# ------------------------------------------------------------------------------
# Monitoring Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  metadata {
    name = local.monitoring_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# ------------------------------------------------------------------------------
# Prometheus + Grafana Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "56.0.0"

  set {
    name  = "grafana.enabled"
    value = tostring(var.enable_grafana)
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "100Gi"
  }

  values = [
    <<-EOT
    grafana:
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: 1
          providers:
            - name: 'nexus'
              orgId: 1
              folder: 'Nexus Platform'
              type: file
              disableDeletion: false
              editable: true
              options:
                path: /var/lib/grafana/dashboards/nexus
      dashboards:
        nexus:
          mttp-cve:
            url: https://raw.githubusercontent.com/example-org/nexus-platform/main/kubernetes/grafana-dashboards/mttp-cve-dashboard.json
          supply-chain:
            url: https://raw.githubusercontent.com/example-org/nexus-platform/main/kubernetes/grafana-dashboards/supply-chain-security.json
          runtime-threats:
            url: https://raw.githubusercontent.com/example-org/nexus-platform/main/kubernetes/grafana-dashboards/runtime-threat-detection.json
          pipeline-gates:
            url: https://raw.githubusercontent.com/example-org/nexus-platform/main/kubernetes/grafana-dashboards/pipeline-security-gates.json
    EOT
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for Pipeline Executions
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "pipeline_executions" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/nexus/platform/pipeline-executions"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-pipeline-executions"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}
