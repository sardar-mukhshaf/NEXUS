# Minimal overrides for dev environment
environment                 = "dev"
cluster_endpoint_public_access = true
security_level              = "standard"
drift_auto_remediate        = false
rollback_requires_approval  = false
node_groups = {
  system = {
    desired_size   = 1
    min_size       = 1
    max_size       = 3
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = { workload-type = "system", cost-center = "platform" }
    taints = []
  }
  workloads = {
    desired_size   = 1
    min_size       = 1
    max_size       = 5
    instance_types = ["t3.xlarge"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = { workload-type = "workloads", cost-center = "shared" }
    taints = []
  }
}
