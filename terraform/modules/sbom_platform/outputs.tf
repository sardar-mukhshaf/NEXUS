output "sbom_bucket_arn" {
  description = "ARN of the SBOM S3 bucket"
  value       = aws_s3_bucket.sbom.arn
}

output "dependency_track_db_endpoint" {
  description = "Endpoint of the Dependency-Track RDS instance"
  value       = var.dependency_track_enabled ? aws_db_instance.dependency_track[0].endpoint : null
  sensitive   = true
}
