variable "project_name" { type = string }
variable "environment" { type = string }
variable "naming_prefix" { type = string }
variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "cluster_endpoint_public_access" { type = bool }
variable "cluster_endpoint_private_access" { type = bool }

variable "node_groups" {
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

variable "fargate_profiles" {
  type = map(object({
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
  }))
  default = {}
}

variable "cluster_pod_security_standard" { type = string }
variable "enable_guardduty" { type = bool }
variable "enable_security_hub" { type = bool }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "common_tags" { type = map(string) }
variable "git_commit_sha" { type = string }
variable "resource_description" { type = string }
