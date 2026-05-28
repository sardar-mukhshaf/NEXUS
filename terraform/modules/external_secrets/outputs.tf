output "eso_irsa_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = "aws-secrets-manager"
}

output "github_token_secret_arn" {
  description = "ARN of the GitHub token secret in Secrets Manager"
  value       = aws_secretsmanager_secret.github_token.arn
}
