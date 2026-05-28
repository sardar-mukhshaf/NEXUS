output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "argocd_irsa_role_arn" {
  description = "IRSA role ARN for ArgoCD"
  value       = aws_iam_role.argocd.arn
}
