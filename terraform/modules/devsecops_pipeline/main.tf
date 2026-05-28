# =============================================================================
# DevSecOps Pipeline Module
# ECR repositories, GitHub Actions Runner Controller (ARC) on EKS.
# =============================================================================

# ------------------------------------------------------------------------------
# ECR Repository
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "microservice" {
  for_each = toset(["nexus-platform", "nexus-backstage"])

  name                 = each.value
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(var.common_tags, {
    Name        = each.value
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_ecr_lifecycle_policy" "microservice" {
  for_each = aws_ecr_repository.microservice

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_lifecycle_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_lifecycle_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "microservice" {
  for_each = aws_ecr_repository.microservice

  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSClusterPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.naming_prefix}-eks-node-role"
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# GitHub Actions Runner Controller (ARC) Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "arc" {
  count = var.enable_arc ? 1 : 0

  metadata {
    name = var.arc_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# ------------------------------------------------------------------------------
# ARC Runner Deployment
# ------------------------------------------------------------------------------
resource "helm_release" "arc" {
  count = var.enable_arc ? 1 : 0

  name       = "arc"
  namespace  = kubernetes_namespace.arc[0].metadata[0].name
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-controller"
  version    = "0.23.7"

  set {
    name  = "replicaCount"
    value = var.arc_runner_replicas
  }

  set {
    name  = "authSecret.create"
    value = "true"
  }

  set {
    name  = "authSecret.github_token"
    value = "${data.aws_secretsmanager_secret_version.github_token.secret_string}"
  }

  depends_on = [kubernetes_namespace.arc]
}

# ------------------------------------------------------------------------------
# ARC Runner Deployment (Runner Set)
# ------------------------------------------------------------------------------
resource "helm_release" "arc_runner_set" {
  count = var.enable_arc ? 1 : 0

  name       = "arc-runner-set"
  namespace  = kubernetes_namespace.arc[0].metadata[0].name
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-set"
  version    = "0.23.7"

  set {
    name  = "runnerDeploymentSpec.replicas"
    value = var.arc_runner_replicas
  }

  set {
    name  = "runnerDeploymentSpec.template.spec.repository"
    value = "example-org/nexus-platform"
  }

  set {
    name  = "runnerDeploymentSpec.template.spec.labels[0]"
    value = "nexus-arc"
  }

  depends_on = [helm_release.arc]
}

# ------------------------------------------------------------------------------
# Network Policy for ARC Runners
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy" "arc" {
  count = var.enable_arc ? 1 : 0

  metadata {
    name      = "arc-runner-network-policy"
    namespace = kubernetes_namespace.arc[0].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "${var.naming_prefix}/github-token"
}
