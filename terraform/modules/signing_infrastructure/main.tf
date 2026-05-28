# =============================================================================
# Signing Infrastructure Module
# KMS key for Cosign image signing, keyless signing support.
# =============================================================================

# ------------------------------------------------------------------------------
# KMS Asymmetric Key for Cosign
# ------------------------------------------------------------------------------
resource "aws_kms_key" "cosign" {
  count = var.enable_cosign_kms ? 1 : 0

  description              = "Cosign image signing key"
  deletion_window_in_days  = 30
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P384"
  enable_key_rotation      = false  # Asymmetric keys do not support automatic rotation

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
        Sid    = "Allow GitHub Actions Runner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-arc-runner-*"
        }
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Kyverno Verification"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-kyverno-*"
        }
        Action = [
          "kms:GetPublicKey",
          "kms:DescribeKey",
          "kms:Verify"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Admin Roles"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/admin"
        }
        Action   = "kms:*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-cosign-kms"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "cosign" {
  count = var.enable_cosign_kms ? 1 : 0

  name          = var.cosign_kms_key_alias
  target_key_id = aws_kms_key.cosign[0].key_id
}

# ------------------------------------------------------------------------------
# GitHub OIDC Provider (if not already existing)
# ------------------------------------------------------------------------------
data "aws_iam_openid_connect_provider" "github" {
  count = var.enable_keyless_signing ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_signing" {
  count = var.enable_keyless_signing ? 1 : 0

  name = "${var.naming_prefix}-github-actions-signing"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : try(data.aws_iam_openid_connect_provider.github[0].arn, "")
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:example-org/*"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-github-actions-signing"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "github_actions_signing" {
  count = var.enable_keyless_signing ? 1 : 0

  name = "${var.naming_prefix}-github-actions-signing-policy"
  role = aws_iam_role.github_actions_signing[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCosignSigning"
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.cosign[0].arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# S3 Bucket for Cosign public key storage
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "cosign_public_keys" {
  count = var.enable_cosign_kms ? 1 : 0

  bucket = "${var.naming_prefix}-cosign-public-keys"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-cosign-public-keys"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "cosign_public_keys" {
  count = var.enable_cosign_kms ? 1 : 0

  bucket = aws_s3_bucket.cosign_public_keys[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cosign_public_keys" {
  count = var.enable_cosign_kms ? 1 : 0

  bucket = aws_s3_bucket.cosign_public_keys[0].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
