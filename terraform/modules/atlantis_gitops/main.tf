# =============================================================================
# Atlantis GitOps Module
# Deploys Atlantis on EKS with IRSA, persistent volume, and webhook ingress.
# =============================================================================

locals {
  atlantis_namespace = "atlantis"
}

# ------------------------------------------------------------------------------
# IRSA for Atlantis
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "atlantis_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.atlantis_namespace}:atlantis"]
    }
  }
}

resource "aws_iam_role" "atlantis" {
  name               = "${var.naming_prefix}-atlantis-irsa"
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-atlantis-irsa"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "atlantis" {
  name = "${var.naming_prefix}-atlantis-policy"
  role = aws_iam_role.atlantis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.naming_prefix}-platform-tfstate",
          "arn:aws:s3:::${var.naming_prefix}-platform-tfstate/*"
        ]
      },
      {
        Sid    = "AllowDynamoDBLocks"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.atlantis_dynamodb_table}"
      },
      {
        Sid    = "AllowEC2Read"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# DynamoDB Table for Atlantis Locks
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "atlantis_locks" {
  name         = var.atlantis_dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.common_tags, {
    Name        = var.atlantis_dynamodb_table
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}
