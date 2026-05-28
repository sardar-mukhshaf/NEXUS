# =============================================================================
# Policy Engine Module
# Deploys Conftest policies and OPA evaluation infrastructure.
# =============================================================================

# ------------------------------------------------------------------------------
# S3 Bucket for Policy Artifacts
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "policies" {
  bucket = "${var.naming_prefix}-policies"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-policies"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "policies" {
  bucket = aws_s3_bucket.policies.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "policies" {
  bucket = aws_s3_bucket.policies.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Upload Conftest Policies
# ------------------------------------------------------------------------------
resource "aws_s3_object" "conftest_policies" {
  for_each = fileset("${path.module}/../../../policies/conftest/terraform", "*.rego")

  bucket = aws_s3_bucket.policies.id
  key    = "conftest/terraform/${each.value}"
  source = "${path.module}/../../../policies/conftest/terraform/${each.value}"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-policy-${each.value}"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# Upload OPA Policies
# ------------------------------------------------------------------------------
resource "aws_s3_object" "opa_policies" {
  for_each = fileset("${path.module}/../../../policies/opa/terraform", "*.rego")

  bucket = aws_s3_bucket.policies.id
  key    = "opa/terraform/${each.value}"
  source = "${path.module}/../../../policies/opa/terraform/${each.value}"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-opa-policy-${each.value}"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}
