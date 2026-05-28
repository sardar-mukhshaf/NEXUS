output "cosign_kms_key_arn" {
  description = "ARN of the Cosign KMS signing key"
  value       = var.enable_cosign_kms ? aws_kms_key.cosign[0].arn : null
}

output "cosign_kms_key_id" {
  description = "Key ID of the Cosign KMS signing key"
  value       = var.enable_cosign_kms ? aws_kms_key.cosign[0].key_id : null
}

output "github_actions_signing_role_arn" {
  description = "IRSA role ARN for GitHub Actions signing"
  value       = var.enable_keyless_signing ? aws_iam_role.github_actions_signing[0].arn : null
}
