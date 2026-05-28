output "audit_bucket_arn" {
  description = "ARN of the audit S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.audit[0].arn : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.this[0].arn : null
}

output "audit_kms_key_arn" {
  description = "ARN of the audit KMS key"
  value       = var.enable_cloudtrail ? aws_kms_key.audit[0].arn : null
}

output "audit_sns_topic_arn" {
  description = "ARN of the audit alerts SNS topic"
  value       = var.enable_cloudtrail ? aws_sns_topic.audit_alerts[0].arn : null
}
