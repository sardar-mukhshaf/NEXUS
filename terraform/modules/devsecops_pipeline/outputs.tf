output "ecr_registry_url" {
  description = "URL of the ECR registry"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "Map of repository names to ECR URLs"
  value       = { for k, v in aws_ecr_repository.microservice : k => v.repository_url }
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = var.enable_keyless_signing ? try(data.aws_iam_openid_connect_provider.github[0].arn, "") : ""
}

output "arc_namespace" {
  description = "Namespace for GitHub Actions Runner Controller"
  value       = var.enable_arc ? kubernetes_namespace.arc[0].metadata[0].name : null
}
