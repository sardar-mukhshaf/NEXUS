output "drift_lambda_arn" {
  description = "ARN of the drift detection Lambda"
  value       = var.drift_detection_enabled ? aws_lambda_function.drift_detector[0].arn : null
}

output "drift_sns_topic_arn" {
  description = "ARN of the drift alerts SNS topic"
  value       = aws_sns_topic.drift_alerts.arn
}
