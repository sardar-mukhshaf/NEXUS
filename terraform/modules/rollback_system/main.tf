# =============================================================================
# Rollback System Module
# ArgoCD selfHeal, automated Git revert Lambda on sync failure.
# =============================================================================

locals {
  rollback_lambda_name = "${var.naming_prefix}-rollback-handler"
}

# ------------------------------------------------------------------------------
# Lambda Role for Rollback
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "rollback_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rollback_lambda" {
  name               = "${local.rollback_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.rollback_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${local.rollback_lambda_name}-role"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "rollback_lambda" {
  name = "${local.rollback_lambda_name}-policy"
  role = aws_iam_role.rollback_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.rollback_lambda_name}:*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Rollback Lambda Function
# ------------------------------------------------------------------------------
data "archive_file" "rollback_lambda" {
  count = var.rollback_auto_staging ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/../../../.build/rollback-handler.zip"

  source {
    content  = <<-EOT
      import json
      import os
      import urllib.request

      GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
      REPO = os.environ.get("REPO", "example-org/nexus-platform")
      ENVIRONMENT = os.environ.get("ENVIRONMENT", "staging")

      def handler(event, context):
          print(f"[ROLLBACK] Sync failure detected in {ENVIRONMENT}")

          if ENVIRONMENT != "staging":
              print("[ROLLBACK] Auto-rollback disabled for non-staging environments")
              return {"statusCode": 200, "body": "Skipped"}

          # Revert last commit via GitHub API
          req = urllib.request.Request(
              f"https://api.github.com/repos/{REPO}/git/refs/heads/main",
              headers={
                  "Authorization": f"token {GITHUB_TOKEN}",
                  "Accept": "application/vnd.github.v3+json"
              },
              method="GET"
          )

          try:
              with urllib.request.urlopen(req) as resp:
                  data = json.loads(resp.read())
                  sha = data["object"]["sha"]
                  print(f"[ROLLBACK] Current HEAD: {sha}")
          except Exception as e:
              print(f"[ERROR] Failed to get HEAD: {e}")
              return {"statusCode": 500, "body": str(e)}

          # Get parent commit
          req = urllib.request.Request(
              f"https://api.github.com/repos/{REPO}/git/commits/{sha}",
              headers={
                  "Authorization": f"token {GITHUB_TOKEN}",
                  "Accept": "application/vnd.github.v3+json"
              },
              method="GET"
          )

          try:
              with urllib.request.urlopen(req) as resp:
                  data = json.loads(resp.read())
                  parent_sha = data["parents"][0]["sha"]
                  print(f"[ROLLBACK] Parent commit: {parent_sha}")
          except Exception as e:
              print(f"[ERROR] Failed to get parent: {e}")
              return {"statusCode": 500, "body": str(e)}

          # Reset to parent
          req = urllib.request.Request(
              f"https://api.github.com/repos/{REPO}/git/refs/heads/main",
              data=json.dumps({"sha": parent_sha}).encode(),
              headers={
                  "Authorization": f"token {GITHUB_TOKEN}",
                  "Accept": "application/vnd.github.v3+json",
                  "Content-Type": "application/json"
              },
              method="PATCH"
          )

          try:
              with urllib.request.urlopen(req) as resp:
                  print(f"[ROLLBACK] Reverted to {parent_sha}")
          except Exception as e:
              print(f"[ERROR] Failed to revert: {e}")
              return {"statusCode": 500, "body": str(e)}

          return {"statusCode": 200, "body": json.dumps({"reverted_to": parent_sha})}
    EOT
    filename = "rollback_handler.py"
  }
}

resource "aws_lambda_function" "rollback_handler" {
  count = var.rollback_auto_staging ? 1 : 0

  function_name    = local.rollback_lambda_name
  role             = aws_iam_role.rollback_lambda.arn
  handler          = "rollback_handler.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.rollback_lambda[0].output_path
  source_code_hash = data.archive_file.rollback_lambda[0].output_base64sha256
  timeout          = 60

  environment {
    variables = {
      GITHUB_TOKEN = data.aws_secretsmanager_secret_version.github_token.secret_string
      REPO         = "example-org/nexus-platform"
      ENVIRONMENT  = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name        = local.rollback_lambda_name
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# SNS Topic for ArgoCD Sync Failures
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "argocd_sync_failures" {
  name = "${var.naming_prefix}-argocd-sync-failures"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-argocd-sync-failures"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_sns_topic_subscription" "rollback_lambda" {
  count = var.rollback_auto_staging ? 1 : 0

  topic_arn = aws_sns_topic.argocd_sync_failures.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.rollback_handler[0].arn
}

resource "aws_lambda_permission" "allow_sns" {
  count = var.rollback_auto_staging ? 1 : 0

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rollback_handler[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.argocd_sync_failures.arn
}
