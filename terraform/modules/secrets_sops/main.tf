# =============================================================================
# SOPS + AWS KMS Configuration
# =============================================================================

# ------------------------------------------------------------------------------
# KMS Key for Dev Secrets
# ------------------------------------------------------------------------------
resource "aws_kms_key" "sops_dev" {
  count = var.sops_enabled && var.environment == "dev" ? 1 : 0

  description             = "SOPS encryption key for dev secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Atlantis Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-atlantis-*"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Break-Glass Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-break-glass"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-sops-dev"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "sops_dev" {
  count = var.sops_enabled && var.environment == "dev" ? 1 : 0

  name          = "alias/${var.naming_prefix}-sops-dev"
  target_key_id = aws_kms_key.sops_dev[0].key_id
}

# ------------------------------------------------------------------------------
# KMS Key for Prod Secrets
# ------------------------------------------------------------------------------
resource "aws_kms_key" "sops_prod" {
  count = var.sops_enabled && var.environment == "prod" ? 1 : 0

  description             = "SOPS encryption key for prod secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Atlantis Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-atlantis-*"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Break-Glass Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-break-glass"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-sops-prod"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "sops_prod" {
  count = var.sops_enabled && var.environment == "prod" ? 1 : 0

  name          = "alias/${var.naming_prefix}-sops-prod"
  target_key_id = aws_kms_key.sops_prod[0].key_id
}

# ------------------------------------------------------------------------------
# SOPS Config File in S3 (for reference)
# ------------------------------------------------------------------------------
resource "aws_s3_object" "sops_config" {
  count = var.sops_enabled ? 1 : 0

  bucket = "${var.naming_prefix}-sops-config"
  key    = ".sops.yaml"
  content = templatefile("${path.module}/../../../gitops/sops/.sops.yaml", {
    dev_kms_key  = var.sops_kms_key_arn_dev
    prod_kms_key = var.sops_kms_key_arn_prod
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-sops-config"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
