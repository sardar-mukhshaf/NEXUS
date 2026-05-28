variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "naming_prefix" {
  description = "Computed naming prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDRs"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway"
  type        = bool
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
}

variable "flow_logs_retention_days" {
  description = "Flow logs retention in days"
  type        = number
}

variable "enable_vpc_endpoints" {
  description = "List of VPC endpoints to create"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
}

variable "git_commit_sha" {
  description = "Git commit SHA"
  type        = string
}

variable "resource_description" {
  description = "Resource description"
  type        = string
}
