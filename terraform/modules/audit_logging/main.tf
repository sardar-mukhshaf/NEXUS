# =============================================================================
# Audit Logging Module
# CloudTrail, S3 audit bucket with Object Lock, 7-year retention.
# =============================================================================

locals {
  audit_bucket_name = "${var.cloudtrail_bucket_prefix}-${var.environment}"
}

# ------------------------------------------------------------------------------
# S3 Audit Bucket
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = local.audit_bucket_name

  tags = merge(var.common_tags, {
    Name        = local.audit_bucket_name
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.audit_retention_years * 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit[0].arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.audit[0].arn,
          "${aws_s3_bucket.audit[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# CloudTrail
# ------------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.naming_prefix}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.audit[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.audit[0].arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.audit[0].arn}/*"]
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-cloudtrail"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# KMS Key for CloudTrail Encryption
# ------------------------------------------------------------------------------
resource "aws_kms_key" "audit" {
  count = var.enable_cloudtrail ? 1 : 0

  description             = "KMS key for CloudTrail audit logs"
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
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-audit-kms"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "audit" {
  count = var.enable_cloudtrail ? 1 : 0

  name          = "alias/${var.naming_prefix}-audit"
  target_key_id = aws_kms_key.audit[0].key_id
}

# ------------------------------------------------------------------------------
# SNS Alerts for Critical Events
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "audit_alerts" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.naming_prefix}-audit-alerts"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-audit-alerts"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# Cross-Region Replication Bucket (DR)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "audit_dr" {
  provider = aws.secondary
  count    = var.enable_cloudtrail ? 1 : 0

  bucket = "${local.audit_bucket_name}-dr"

  tags = merge(var.common_tags, {
    Name        = "${local.audit_bucket_name}-dr"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "audit_dr" {
  provider = aws.secondary
  count    = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.audit_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
