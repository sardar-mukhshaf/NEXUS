locals {
  eso_namespace = "external-secrets"
}

# ------------------------------------------------------------------------------
# IRSA for External Secrets Operator
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.eso_namespace}:external-secrets-sa"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.naming_prefix}-eso-irsa"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-eso-irsa"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "eso" {
  name = "${var.naming_prefix}-eso-policy"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/nexus/*"
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# External Secrets Operator Helm Release
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "eso" {
  metadata {
    name = local.eso_namespace
  }
}

resource "helm_release" "external_secrets" {
  count = var.external_secrets_enabled ? 1 : 0

  name       = "external-secrets"
  namespace  = kubernetes_namespace.eso.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_version

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets-sa"
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.eso]
}

# ------------------------------------------------------------------------------
# ClusterSecretStore
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "cluster_secret_store" {
  count = var.external_secrets_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
      annotations = {
        description = "Cluster-wide AWS Secrets Manager provider via IRSA"
      }
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = data.aws_region.current.name
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets-sa"
                namespace = local.eso_namespace
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

# ------------------------------------------------------------------------------
# Example ExternalSecret
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "example_external_secret" {
  count = var.external_secrets_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "example-db-credentials"
      namespace = "default"
      annotations = {
        description = "Example ExternalSecret syncing from AWS Secrets Manager"
      }
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = "aws-secrets-manager"
      }
      target = {
        name           = "db-credentials"
        creationPolicy = "Owner"
        deletionPolicy = "Retain"
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = "nexus/dev/db-credentials"
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = "nexus/dev/db-credentials"
            property = "password"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

# Store GitHub token in Secrets Manager for reference
resource "aws_secretsmanager_secret" "github_token" {
  name        = "${var.naming_prefix}/github-token"
  description = "GitHub token for Atlantis and CI/CD pipelines"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-github-token"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}
