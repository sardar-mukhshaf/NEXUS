output "falco_namespace" {
  description = "Namespace where Falco is deployed"
  value       = local.falco_namespace
}

output "falco_irsa_role_arn" {
  description = "IRSA role ARN for Falco"
  value       = aws_iam_role.falco.arn
}
