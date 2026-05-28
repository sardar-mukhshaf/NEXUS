# Minimal overrides for production environment
environment                    = "prod"
cluster_endpoint_public_access = false
security_level                 = "maximum"
drift_auto_remediate           = true
rollback_requires_approval     = true
cluster_pod_security_standard  = "restricted"
