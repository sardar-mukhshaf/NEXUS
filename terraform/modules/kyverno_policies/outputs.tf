output "kyverno_namespace" {
  description = "Namespace where Kyverno is deployed"
  value       = local.kyverno_namespace
}

output "kyverno_policies_enforced" {
  description = "Whether Kyverno policies are enforced"
  value       = var.kyverno_policies_enforce
}
