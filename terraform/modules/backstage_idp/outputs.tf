output "backstage_url" {
  description = "URL of the Backstage IDP"
  value       = var.backstage_enabled ? "https://${var.backstage_domain}" : null
}

output "backstage_db_endpoint" {
  description = "Endpoint of the Backstage RDS instance"
  value       = var.backstage_enabled ? aws_db_instance.backstage[0].endpoint : null
  sensitive   = true
}

output "backstage_techdocs_bucket" {
  description = "S3 bucket for Backstage TechDocs"
  value       = aws_s3_bucket.techdocs.id
}

output "backstage_irsa_role_arn" {
  description = "IRSA role ARN for Backstage"
  value       = aws_iam_role.backstage.arn
}
