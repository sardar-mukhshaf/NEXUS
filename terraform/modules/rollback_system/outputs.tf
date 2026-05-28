output "rollback_lambda_arn" {
  description = "ARN of the rollback handler Lambda"
  value       = var.rollback_auto_staging ? aws_lambda_function.rollback_handler[0].arn : null
}

output "argocd_sync_failures_topic_arn" {
  description = "ARN of the ArgoCD sync failures SNS topic"
  value       = aws_sns_topic.argocd_sync_failures.arn
}
