locals {
  kyverno_namespace = "kyverno"
  system_namespaces = ["kube-system", "kyverno", "falco", "atlantis", "argocd", "external-secrets"]
}

# ------------------------------------------------------------------------------
# Kyverno Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = local.kyverno_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# ------------------------------------------------------------------------------
# Kyverno Helm Release
# ------------------------------------------------------------------------------
resource "helm_release" "kyverno" {
  count = var.kyverno_enabled ? 1 : 0

  name       = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  version    = var.kyverno_version

  set {
    name  = "admissionController.replicas"
    value = "3"
  }

  set {
    name  = "backgroundController.replicas"
    value = "2"
  }

  set {
    name  = "cleanupController.replicas"
    value = "2"
  }

  set {
    name  = "reportsController.replicas"
    value = "2"
  }

  set {
    name  = "features.admission_reports"
    value = "true"
  }

  depends_on = [kubernetes_namespace.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Verify Image Signatures (Cosign)
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "verify_image_signatures" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "verify-image-signatures"
      annotations = {
        policies.kyverno.io/title       = "Verify Image Signatures"
        policies.kyverno.io/category    = "Security"
        policies.kyverno.io/severity    = "critical"
        policies.kyverno.io/subject     = "Pod"
        policies.kyverno.io/description = "Requires all container images to be signed with Cosign KMS key"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "verify-cosign-signature"
          match = {
            resources = {
              kinds = ["Pod"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          verifyImages = [
            {
              imageReferences = ["*"]
              attestors = [
                {
                  entries = [
                    {
                      keys = {
                        kms = var.cosign_kms_key_arn
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Restrict Image Registries
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "restrict_image_registries" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "restrict-image-registries"
      annotations = {
        policies.kyverno.io/title       = "Restrict Image Registries"
        policies.kyverno.io/category    = "Security"
        policies.kyverno.io/severity    = "critical"
        policies.kyverno.io/subject     = "Pod"
        policies.kyverno.io/description = "Only allow images from private ECR registry"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "validate-ecr-registry"
          match = {
            resources = {
              kinds = ["Pod"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          validate = {
            message = "Only images from the private ECR registry are allowed."
            pattern = {
              spec = {
                containers = [
                  {
                    image = "${var.ecr_registry_url}/*"
                  }
                ]
                initContainers = [
                  {
                    image = "${var.ecr_registry_url}/*"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Require Resource Limits
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "require_resource_limits" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-resource-limits"
      annotations = {
        policies.kyverno.io/title       = "Require Resource Limits"
        policies.kyverno.io/category    = "Best Practices"
        policies.kyverno.io/severity    = "high"
        policies.kyverno.io/subject     = "Pod"
        policies.kyverno.io/description = "CPU and memory limits are mandatory for all containers"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "validate-resources"
          match = {
            resources = {
              kinds = ["Pod"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          validate = {
            message = "CPU and memory limits are required."
            pattern = {
              spec = {
                containers = [
                  {
                    resources = {
                      limits = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                      requests = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Require Non-Root
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "require_non_root" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-non-root"
      annotations = {
        policies.kyverno.io/title       = "Require Non-Root Containers"
        policies.kyverno.io/category    = "Security"
        policies.kyverno.io/severity    = "critical"
        policies.kyverno.io/subject     = "Pod"
        policies.kyverno.io/description = "Containers must run as non-root with read-only root filesystem and dropped capabilities"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "check-security-context"
          match = {
            resources = {
              kinds = ["Pod"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          validate = {
            message = "Container must have runAsNonRoot: true, readOnlyRootFilesystem: true, and drop ALL capabilities."
            pattern = {
              spec = {
                securityContext = {
                  runAsNonRoot = true
                }
                containers = [
                  {
                    securityContext = {
                      allowPrivilegeEscalation = false
                      readOnlyRootFilesystem   = true
                      capabilities = {
                        drop = ["ALL"]
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Require GitOps Annotations
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "require_gitops_annotations" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-gitops-annotations"
      annotations = {
        policies.kyverno.io/title       = "Require GitOps Annotations"
        policies.kyverno.io/category    = "Governance"
        policies.kyverno.io/severity    = "medium"
        policies.kyverno.io/subject     = "Deployment"
        policies.kyverno.io/description = "Every deployment must have an ArgoCD tracking ID annotation"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "validate-argocd-annotation"
          match = {
            resources = {
              kinds = ["Deployment", "StatefulSet", "DaemonSet"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          validate = {
            message = "ArgoCD tracking ID annotation is required."
            pattern = {
              metadata = {
                annotations = {
                  "argocd.argoproj.io/tracking-id" = "?*"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Block Manual Secrets
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "block_manual_secrets" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "block-manual-secrets"
      annotations = {
        policies.kyverno.io/title       = "Block Manual Secret Creation"
        policies.kyverno.io/category    = "Security"
        policies.kyverno.io/severity    = "high"
        policies.kyverno.io/subject     = "Secret"
        policies.kyverno.io/description = "Prevents manual creation of secrets via kubectl"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = false
      rules = [
        {
          name = "block-kubectl-create-secret"
          match = {
            resources = {
              kinds = ["Secret"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          preconditions = {
            all = [
              {
                key      = "{{request.operation}}"
                operator = "Equals"
                value    = "CREATE"
              }
            ]
          }
          validate = {
            message = "Manual secret creation is blocked. Use External Secrets Operator instead."
            deny = {
              conditions = {
                all = [
                  {
                    key      = "{{request.operation}}"
                    operator = "Equals"
                    value    = "CREATE"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# ------------------------------------------------------------------------------
# Policy: Enforce Resource Descriptions
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "enforce_resource_descriptions" {
  count = var.kyverno_enabled ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "enforce-resource-descriptions"
      annotations = {
        policies.kyverno.io/title       = "Enforce Resource Descriptions"
        policies.kyverno.io/category    = "Governance"
        policies.kyverno.io/severity    = "low"
        policies.kyverno.io/subject     = "Deployment"
        policies.kyverno.io/description = "Every resource must have a description annotation with at least 10 characters"
      }
    }
    spec = {
      validationFailureAction = var.kyverno_policies_enforce ? "Enforce" : "Audit"
      background              = true
      rules = [
        {
          name = "validate-description"
          match = {
            resources = {
              kinds = ["Deployment", "StatefulSet", "DaemonSet", "Service", "ConfigMap"]
            }
          }
          exclude = {
            resources = {
              namespaces = local.system_namespaces
            }
          }
          validate = {
            message = "Resource must have metadata.annotations.description with at least 10 characters."
            pattern = {
              metadata = {
                annotations = {
                  description = "?*"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}
