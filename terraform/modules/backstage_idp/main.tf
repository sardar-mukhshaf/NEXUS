# =============================================================================
# Backstage IDP Module
# Deploys Backstage.io on EKS with RDS, S3 TechDocs, and SSO.
# =============================================================================

locals {
  backstage_namespace = "backstage"
}

# ------------------------------------------------------------------------------
# IRSA for Backstage
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "backstage_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.backstage_namespace}:backstage"]
    }
  }
}

resource "aws_iam_role" "backstage" {
  name               = "${var.naming_prefix}-backstage-irsa"
  assume_role_policy = data.aws_iam_policy_document.backstage_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-backstage-irsa"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "backstage" {
  name = "${var.naming_prefix}-backstage-policy"
  role = aws_iam_role.backstage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3TechDocs"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.techdocs.arn,
          "${aws_s3_bucket.techdocs.arn}/*"
        ]
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
# RDS PostgreSQL for Backstage
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "backstage" {
  name       = "${var.naming_prefix}-backstage-db"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-backstage-db"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_db_instance" "backstage" {
  count = var.backstage_enabled ? 1 : 0

  identifier             = "${var.naming_prefix}-backstage"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.backstage_db_instance_class
  allocated_storage      = 100
  max_allocated_storage  = 500
  storage_type           = "gp3"
  storage_encrypted      = true
  multi_az               = var.backstage_db_multi_az
  db_name                = "backstage"
  username               = "backstage_admin"
  password               = random_password.backstage[0].result
  db_subnet_group_name   = aws_db_subnet_group.backstage.name
  vpc_security_group_ids = [aws_security_group.backstage_db[0].id]
  backup_retention_period = var.backstage_db_backup_retention
  deletion_protection    = true

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-backstage-db"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "backstage" {
  count = var.backstage_enabled ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_security_group" "backstage_db" {
  count = var.backstage_enabled ? 1 : 0

  name        = "${var.naming_prefix}-backstage-db-sg"
  description = "Security group for Backstage RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-backstage-db-sg"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# S3 Bucket for TechDocs
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "techdocs" {
  bucket = "${var.backstage_techdocs_bucket_prefix}-${var.environment}"

  tags = merge(var.common_tags, {
    Name        = "${var.backstage_techdocs_bucket_prefix}-${var.environment}"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
