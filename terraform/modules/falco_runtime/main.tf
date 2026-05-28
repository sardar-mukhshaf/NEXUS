# =============================================================================
# Falco Runtime Module
# Deploys Falco DaemonSet with eBPF probe and Falcosidekick alerting.
# =============================================================================

locals {
  falco_namespace = "falco"
}

# ------------------------------------------------------------------------------
# Falco Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "falco" {
  metadata {
    name = local.falco_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# ------------------------------------------------------------------------------
# IRSA for Falco
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "falco_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.falco_namespace}:falco"]
    }
  }
}

resource "aws_iam_role" "falco" {
  name               = "${var.naming_prefix}-falco-irsa"
  assume_role_policy = data.aws_iam_policy_document.falco_assume_role.json

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-falco-irsa"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_iam_role_policy" "falco" {
  name = "${var.naming_prefix}-falco-policy"
  role = aws_iam_role.falco.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Archive"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.naming_prefix}-falco-archive/*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Falco Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "falco" {
  count = var.falco_enabled ? 1 : 0

  name       = "falco"
  namespace  = kubernetes_namespace.falco.metadata[0].name
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  version    = var.falco_version

  set {
    name  = "driver.kind"
    value = var.falco_ebpf_enabled ? "ebpf" : "kmod"
  }

  set {
    name  = "collectors.enabled"
    value = "true"
  }

  set {
    name  = "tty"
    value = "true"
  }

  values = [
    <<-EOT
    customRules:
      custom-rules.yaml: |
        - rule: Crypto Mining Detection
          desc: Detect connections to known crypto mining pools
          condition: >
            spawned_process and
            (proc.name in ("xmrig", "minerd", "cgminer", "bfgminer") or
            (fd.name contains "stratum+tcp" or fd.name contains "pool.minergate"))
          output: >
            Crypto mining process detected
            user=%user.name command=%proc.cmdline pid=%proc.pid
          priority: CRITICAL
          tags: [crypto, mining]

        - rule: Reverse Shell Detection
          desc: Detect reverse shell attempts
          condition: >
            spawned_process and
            (proc.name in ("bash", "sh", "python", "python3", "nc", "ncat") and
             (proc.cmdline contains "/dev/tcp/" or proc.cmdline contains "/dev/udp/"))
          output: >
            Reverse shell detected
            user=%user.name command=%proc.cmdline
          priority: CRITICAL
          tags: [shell, reverse]
    EOT
  ]

  depends_on = [kubernetes_namespace.falco]
}

# ------------------------------------------------------------------------------
# Falcosidekick Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "falcosidekick" {
  count = var.falco_enabled && var.falcosidekick_enabled ? 1 : 0

  name       = "falcosidekick"
  namespace  = kubernetes_namespace.falco.metadata[0].name
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falcosidekick"
  version    = "0.7.0"

  set {
    name  = "config.slack.webhookurl"
    value = "${var.slack_webhook_url}"
  }

  set {
    name  = "config.pagerduty.routingKey"
    value = "${var.pagerduty_integration_key}"
  }

  set {
    name  = "config.aws.s3.bucket"
    value = "${var.naming_prefix}-falco-archive"
  }

  depends_on = [helm_release.falco]
}

# ------------------------------------------------------------------------------
# S3 Bucket for Falco Archive
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "falco_archive" {
  bucket = "${var.naming_prefix}-falco-archive"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-falco-archive"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "falco_archive" {
  bucket = aws_s3_bucket.falco_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "falco_archive" {
  bucket = aws_s3_bucket.falco_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
