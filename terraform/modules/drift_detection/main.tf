# =============================================================================
# Drift Detection Module
# Python Lambda comparing Terraform state to live AWS resources.
# =============================================================================

locals {
  lambda_name = "${var.naming_prefix}-drift-detector"
}

# ------------------------------------------------------------------------------
# IAM Role for Lambda
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "drift_lambda" {
  name               = "${local.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${local.lambda_name}-role"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "drift_lambda" {
  name = "${local.lambda_name}-policy"
  role = aws_iam_role.drift_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/${var.terraform_state_key}"
        ]
      },
      {
        Sid    = "DescribeAWSResources"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "iam:GetPolicy",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "PublishNotifications"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.drift_alerts.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.lambda_name}:*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Lambda Function
# ------------------------------------------------------------------------------
data "archive_file" "drift_lambda" {
  count = var.drift_detection_enabled ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/../../../.build/drift-detector.zip"

  source {
    content  = file("${path.module}/../../../scripts/drift-detector.py")
    filename = "drift-detector.py"
  }
}

resource "aws_lambda_function" "drift_detector" {
  count = var.drift_detection_enabled ? 1 : 0

  function_name    = local.lambda_name
  role             = aws_iam_role.drift_lambda.arn
  handler          = "drift-detector.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.drift_lambda[0].output_path
  source_code_hash = data.archive_file.drift_lambda[0].output_base64sha256
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      STATE_BUCKET       = var.terraform_state_bucket
      STATE_KEY          = var.terraform_state_key
      SNS_TOPIC_ARN      = aws_sns_topic.drift_alerts.arn
      ENVIRONMENT        = var.environment
      AUTO_REMEDIATE     = tostring(var.drift_auto_remediate)
      ATLANTIS_WEBHOOK_URL = "https://${var.naming_prefix}-atlantis.nexus-platform.local/events"
    }
  }

  tags = merge(var.common_tags, {
    Name        = local.lambda_name
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# EventBridge Schedule
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "drift_schedule" {
  count = var.drift_detection_enabled ? 1 : 0

  name                = "${local.lambda_name}-schedule"
  description         = "Trigger drift detection Lambda"
  schedule_expression = var.drift_check_interval

  tags = merge(var.common_tags, {
    Name        = "${local.lambda_name}-schedule"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_cloudwatch_event_target" "drift_lambda" {
  count = var.drift_detection_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.drift_schedule[0].name
  target_id = "DriftDetectorLambda"
  arn       = aws_lambda_function.drift_detector[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.drift_detection_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drift_detector[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.drift_schedule[0].arn
}

# ------------------------------------------------------------------------------
# SNS Topic for Drift Alerts
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "drift_alerts" {
  name = "${local.lambda_name}-alerts"

  tags = merge(var.common_tags, {
    Name        = "${local.lambda_name}-alerts"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_sns_topic_subscription" "drift_email" {
  count = var.drift_detection_enabled && var.drift_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.drift_alerts.arn
  protocol  = "email"
  endpoint  = var.drift_notification_email
}
