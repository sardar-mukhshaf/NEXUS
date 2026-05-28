output "policies_bucket_arn" {
  description = "ARN of the policies S3 bucket"
  value       = aws_s3_bucket.policies.arn
}

output "policies_bucket_name" {
  description = "Name of the policies S3 bucket"
  value       = aws_s3_bucket.policies.id
}
