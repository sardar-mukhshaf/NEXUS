output "team_namespaces" {
  description = "Map of team names to created namespace names"
  value       = { for k, v in kubernetes_namespace.microservice : k => v.metadata[0].name }
}

output "team_irsa_roles" {
  description = "Map of team names to IRSA role ARNs"
  value       = { for k, v in aws_iam_role.microservice : k => v.arn }
}

output "team_rds_endpoints" {
  description = "Map of team names to RDS endpoints"
  value       = { for k, v in aws_db_instance.microservice : k => v.endpoint }
  sensitive   = true
}

output "team_sqs_urls" {
  description = "Map of team names to SQS queue URLs"
  value       = { for k, v in aws_sqs_queue.microservice : k => v.id }
}

output "team_s3_buckets" {
  description = "Map of team names to S3 bucket names"
  value       = { for k, v in aws_s3_bucket.microservice : k => v.id }
}
