locals {
  argocd_namespace = "argocd"
}

# ------------------------------------------------------------------------------
# IRSA for ArgoCD
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "argocd_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.argocd_namespace}:argocd-application-controller"]
    }
  }
}

resource "aws_iam_role" "argocd" {
  name               = "${var.naming_prefix}-argocd-irsa"
  assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-argocd-irsa"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "argocd" {
  name = "${var.naming_prefix}-argocd-policy"
  role = aws_iam_role.argocd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3Read"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ArgoCD Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# ArgoCD Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  set {
    name  = "configs.cm.application.resourceTrackingMethod"
    value = "annotation"
  }

  set {
    name  = "configs.rbac.policy.default"
    value = "role:readonly"
  }

  set {
    name  = "configs.rbac.policy.csv"
    value = <<-EOT
      p, role:dev-team, applications, sync, dev-*/, allow
      p, role:platform-admin, applications, *, */, allow
      g, platform-engineering, role:platform-admin
    EOT
  }

  set {
    name  = "controller.selfHeal"
    value = tostring(var.argocd_self_heal)
  }

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.args.appResyncPeriod"
    value = "300"
  }

  set {
    name  = "repoServer.volumes[0].name"
    value = "sops-age"
  }

  set {
    name  = "repoServer.volumes[0].secret.secretName"
    value = "sops-age-key"
  }

  set {
    name  = "repoServer.volumeMounts[0].name"
    value = "sops-age"
  }

  set {
    name  = "repoServer.volumeMounts[0].mountPath"
    value = "/sops"
  }

  values = [
    <<-EOT
    configs:
      cmp:
        create: true
        plugins:
          sops-decrypt:
            init:
              command: [sh, -c]
              args:
                - |
                  apt-get update && apt-get install -y curl && \
                  curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 && \
                  install -m 755 sops-v3.8.1.linux.amd64 /usr/local/bin/sops
            generate:
              command: [sh, -c]
              args:
                - |
                  find . -name '*.enc.yaml' -exec sops -d {} \;
                  cat .
    EOT
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ------------------------------------------------------------------------------
# ArgoCD Self-Management Application
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "argocd_self_management" {
  count = var.argocd_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "argocd-self-management"
      namespace = local.argocd_namespace
      annotations = {
        description   = "ArgoCD manages its own Helm release and configuration"
        "managed-by"  = "terraform"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/example-org/nexus-platform.git"
        targetRevision = "HEAD"
        path           = "gitops/argocd-apps/self-management"
        helm = {
          values = <<-EOT
            argo-cd:
              configs:
                cm:
                  application.resourceTrackingMethod: annotation
                rbac:
                  policy.default: role:readonly
                  policy.csv: |
                    p, role:dev-team, applications, sync, dev-*/, allow
                    p, role:platform-admin, applications, *, */, allow
                    g, platform-engineering, role:platform-admin
              controller:
                selfHeal: true
              server:
                extraArgs:
                  - --insecure
          EOT
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          selfHeal = var.argocd_self_heal
          prune    = var.argocd_prune
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ------------------------------------------------------------------------------
# ArgoCD ApplicationSet for Teams
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "team_applicationset" {
  count = var.argocd_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "team-services"
      namespace = local.argocd_namespace
    }
    spec = {
      generators = [
        {
          git = {
            repoURL  = "https://github.com/example-org/nexus-platform.git"
            revision = "HEAD"
            directories = [
              { path = "gitops/teams/*" }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name = "{{path.basename}}"
          annotations = {
            "argocd.argoproj.io/tracking-id" = "{{path.basename}}"
          }
        }
        spec = {
          project = "default"
          source = {
            repoURL        = "https://github.com/example-org/nexus-platform.git"
            targetRevision = "HEAD"
            path           = "{{path}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"
          }
          syncPolicy = {
            automated = {
              selfHeal = true
              prune    = true
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
