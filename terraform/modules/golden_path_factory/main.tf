# =============================================================================
# Golden Path Factory Module
# Reusable Terraform sub-modules for microservice infrastructure.
# =============================================================================

# ------------------------------------------------------------------------------
# Microservice Namespace Submodule
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "microservice" {
  for_each = var.cost_centers

  metadata {
    name = "${each.key}-${var.environment}"
    labels = {
      team        = each.key
      cost-center = each.value
      environment = var.environment
    }
    annotations = {
      description = "Namespace for ${each.key} team microservices"
    }
  }
}

resource "kubernetes_resource_quota" "microservice" {
  for_each = var.cost_centers

  metadata {
    name      = "${each.key}-quota"
    namespace = kubernetes_namespace.microservice[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "20"
      "requests.memory" = "40Gi"
      "limits.cpu"      = "40"
      "limits.memory"   = "80Gi"
      "pods"            = "50"
      "services"        = "20"
      "persistentvolumeclaims" = "10"
    }
  }
}

resource "kubernetes_limit_range" "microservice" {
  for_each = var.cost_centers

  metadata {
    name      = "${each.key}-limits"
    namespace = kubernetes_namespace.microservice[each.key].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = {
        cpu    = "4"
        memory = "8Gi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_network_policy" "microservice" {
  for_each = var.cost_centers

  metadata {
    name      = "${each.key}-network-policy"
    namespace = kubernetes_namespace.microservice[each.key].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            team = each.key
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {}
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
          except = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Microservice RDS Submodule
# ------------------------------------------------------------------------------
resource "aws_db_instance" "microservice" {
  for_each = var.cost_centers

  identifier             = "${var.naming_prefix}-${each.key}"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.t4g.medium"
  allocated_storage      = 50
  max_allocated_storage  = 200
  storage_type           = "gp3"
  storage_encrypted      = true
  multi_az               = var.environment == "prod"
  db_name                = replace(each.key, "-", "_")
  username               = "${replace(each.key, "-", "_")}_admin"
  password               = random_password.microservice[each.key].result
  db_subnet_group_name   = aws_db_subnet_group.microservice.name
  vpc_security_group_ids = [aws_security_group.microservice_db.id]
  backup_retention_period = 7
  deletion_protection    = var.environment == "prod"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-${each.key}"
    Team        = each.key
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "random_password" "microservice" {
  for_each = var.cost_centers

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "microservice" {
  name       = "${var.naming_prefix}-microservices"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-microservices-db"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_security_group" "microservice_db" {
  name        = "${var.naming_prefix}-microservices-db-sg"
  description = "Security group for microservice RDS instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-microservices-db-sg"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# ------------------------------------------------------------------------------
# Microservice SQS Submodule
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "microservice" {
  for_each = var.cost_centers

  name                       = "${var.naming_prefix}-${each.key}"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 300
  kms_master_key_id          = "alias/aws/sqs"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-${each.key}"
    Team        = each.key
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_sqs_queue" "microservice_dlq" {
  for_each = var.cost_centers

  name                      = "${var.naming_prefix}-${each.key}-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-${each.key}-dlq"
    Team        = each.key
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_sqs_queue_redrive_policy" "microservice" {
  for_each = var.cost_centers

  queue_url = aws_sqs_queue.microservice[each.key].id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.microservice_dlq[each.key].arn
    maxReceiveCount     = 5
  })
}

# ------------------------------------------------------------------------------
# Microservice S3 Submodule
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "microservice" {
  for_each = var.cost_centers

  bucket = "${var.naming_prefix}-${each.key}-${var.environment}"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-${each.key}"
    Team        = each.key
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "microservice" {
  for_each = var.cost_centers

  bucket = aws_s3_bucket.microservice[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "microservice" {
  for_each = var.cost_centers

  bucket = aws_s3_bucket.microservice[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "microservice" {
  for_each = var.cost_centers

  bucket = aws_s3_bucket.microservice[each.key].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "microservice" {
  for_each = var.cost_centers

  bucket = aws_s3_bucket.microservice[each.key].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# ------------------------------------------------------------------------------
# Microservice IRSA Submodule
# ------------------------------------------------------------------------------
resource "aws_iam_role" "microservice" {
  for_each = var.cost_centers

  name = "${var.naming_prefix}-${each.key}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${each.key}-${var.environment}:default"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-${each.key}-irsa"
    Team        = each.key
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "microservice" {
  for_each = var.cost_centers

  name = "${var.naming_prefix}-${each.key}-policy"
  role = aws_iam_role.microservice[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.microservice[each.key].arn,
          "${aws_s3_bucket.microservice[each.key].arn}/*"
        ]
      },
      {
        Sid    = "AllowSQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.microservice[each.key].arn
      },
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret/${var.naming_prefix}/${each.key}/*"
      }
    ]
  })
}
