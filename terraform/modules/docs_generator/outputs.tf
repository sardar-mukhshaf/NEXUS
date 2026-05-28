output "docs_bucket_arn" {
  description = "ARN of the documentation S3 bucket"
  value       = aws_s3_bucket.docs.arn
}

output "docs_bucket_name" {
  description = "Name of the documentation S3 bucket"
  value       = aws_s3_bucket.docs.id
}
