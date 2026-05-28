output "kubecost_namespace" {
  description = "Namespace where Kubecost is deployed"
  value       = var.enable_kubecost ? kubernetes_namespace.kubecost[0].metadata[0].name : null
}

output "kubecost_enabled" {
  description = "Whether Kubecost is enabled"
  value       = var.enable_kubecost
}
