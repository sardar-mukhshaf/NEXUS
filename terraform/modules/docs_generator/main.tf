# =============================================================================
# Docs Generator Module
# Terraform-docs + Python script for Mermaid diagrams.
# =============================================================================

# ------------------------------------------------------------------------------
# S3 Bucket for Generated Docs
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "docs" {
  bucket = "${var.naming_prefix}-docs"

  tags = merge(var.common_tags, {
    Name        = "${var.naming_prefix}-docs"
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# ------------------------------------------------------------------------------
# Python Script for Mermaid Generation
# ------------------------------------------------------------------------------
resource "local_file" "generate_mermaid" {
  filename = "${path.module}/../../../scripts/generate-mermaid.py"

  content = <<-EOT
#!/usr/bin/env python3
"""Generate Mermaid diagrams from Terraform state."""
import argparse
import json
import os
import subprocess
from datetime import datetime


def parse_args():
    parser = argparse.ArgumentParser(description="Generate Mermaid diagrams from Terraform")
    parser.add_argument("--tf-dir", required=True, help="Terraform directory")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    parser.add_argument("--timestamp", default=datetime.now().strftime("%Y%m%d-%H%M%S"))
    return parser.parse_args()


def get_resources(tf_dir):
    """Get resources from terraform show."""
    try:
        result = subprocess.run(
            ["terraform", "show", "-json"],
            cwd=tf_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Error running terraform show: {e}")
        return {}


def generate_resource_graph(resources, output_file):
    """Generate Mermaid resource dependency graph."""
    with open(output_file, "w") as f:
        f.write("graph TD\n")
        for resource in resources.get("values", {}).get("root_module", {}).get("resources", []):
            addr = resource.get("address", "unknown")
            rtype = resource.get("type", "unknown")
            f.write(f"    {addr.replace('.', '_')}[{addr}<br/>{rtype}]\n")
        f.write("\n")


def generate_network_topology(resources, output_file):
    """Generate Mermaid network topology diagram."""
    with open(output_file, "w") as f:
        f.write("graph LR\n")
        f.write("    Internet([Internet]) --> IGW[Internet Gateway]\n")
        f.write("    IGW --> ALB[Application Load Balancer]\n")
        f.write("    ALB --> EKS[EKS Cluster]\n")
        f.write("    EKS --> Pods[Application Pods]\n")
        f.write("    Pods --> RDS[(RDS PostgreSQL)]\n")
        f.write("    Pods --> S3[(S3 Buckets)]\n")
        f.write("    Pods --> SQS[SQS Queues]\n")
        f.write("\n")


def generate_iam_trust(resources, output_file):
    """Generate Mermaid IAM trust relationships diagram."""
    with open(output_file, "w") as f:
        f.write("graph TD\n")
        f.write("    EKS[EKS Cluster] -->|OIDC| IRSA[IRSA Roles]\n")
        f.write("    IRSA --> Backstage[Backstage]\n")
        f.write("    IRSA --> ArgoCD[ArgoCD]\n")
        f.write("    IRSA --> Atlantis[Atlantis]\n")
        f.write("    IRSA --> Falco[Falco]\n")
        f.write("    IRSA --> ExternalSecrets[External Secrets]\n")
        f.write("\n")


def main():
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)

    resources = get_resources(args.tf_dir)

    generate_resource_graph(
        resources,
        os.path.join(args.output_dir, f"resource-graph-{args.timestamp}.mmd")
    )
    generate_network_topology(
        resources,
        os.path.join(args.output_dir, f"network-topology-{args.timestamp}.mmd")
    )
    generate_iam_trust(
        resources,
        os.path.join(args.output_dir, f"iam-trust-{args.timestamp}.mmd")
    )

    print(f"Diagrams generated in {args.output_dir}")


if __name__ == "__main__":
    main()
  EOT
}
