output "sops_dev_kms_key_arn" {
  description = "ARN of the dev SOPS KMS key"
  value       = var.sops_enabled && var.environment == "dev" ? aws_kms_key.sops_dev[0].arn : null
}

output "sops_prod_kms_key_arn" {
  description = "ARN of the prod SOPS KMS key"
  value       = var.sops_enabled && var.environment == "prod" ? aws_kms_key.sops_prod[0].arn : null
}
