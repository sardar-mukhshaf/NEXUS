output "atlantis_url" {
  description = "URL of the Atlantis server"
  value       = var.atlantis_enabled ? "https://${var.atlantis_domain}" : null
}

output "atlantis_irsa_role_arn" {
  description = "IRSA role ARN for Atlantis"
  value       = aws_iam_role.atlantis.arn
}

output "atlantis_dynamodb_table" {
  description = "DynamoDB table for Atlantis locks"
  value       = aws_dynamodb_table.atlantis_locks.name
}
