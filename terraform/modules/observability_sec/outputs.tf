output "monitoring_namespace" {
  description = "Namespace where monitoring stack is deployed"
  value       = local.monitoring_namespace
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for pipeline executions"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.pipeline_executions[0].name : null
}
