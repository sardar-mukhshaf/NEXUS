# =============================================================================
# SBOM Platform Module
# Dependency-Track on EKS with RDS PostgreSQL backend and S3 storage.
# =============================================================================

locals {
  dependency_track_namespace = "dependency-track"
}

# ------------------------------------------------------------------------------
# Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "dependency_track" {
  metadata {
    name = local.dependency_track_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# ------------------------------------------------------------------------------
# S3 Bucket for SBOM Storage
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "sbom" {
  bucket = "${var.naming_prefix}-sboms"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-sboms"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "sbom" {
  bucket = aws_s3_bucket.sbom.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sbom" {
  bucket = aws_s3_bucket.sbom.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# ------------------------------------------------------------------------------
# RDS for Dependency-Track
# ------------------------------------------------------------------------------
resource "aws_db_instance" "dependency_track" {
  count = var.dependency_track_enabled ? 1 : 0

  identifier             = "${var.naming_prefix}-dependency-track"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.dependency_track_db_class
  allocated_storage      = 100
  max_allocated_storage  = 500
  storage_type           = "gp3"
  storage_encrypted      = true
  multi_az               = var.environment == "prod"
  db_name                = "dependency_track"
  username               = "dtrack_admin"
  password               = random_password.dependency_track[0].result
  db_subnet_group_name   = aws_db_subnet_group.dependency_track.name
  vpc_security_group_ids = [aws_security_group.dependency_track[0].id]
  backup_retention_period = 7

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-dependency-track-db"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "random_password" "dependency_track" {
  count = var.dependency_track_enabled ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "dependency_track" {
  name       = "${var.naming_prefix}-dependency-track"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-dependency-track"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_security_group" "dependency_track" {
  count = var.dependency_track_enabled ? 1 : 0

  name        = "${var.naming_prefix}-dependency-track-db-sg"
  description = "Security group for Dependency-Track RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-dependency-track-db-sg"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}
