# Compliance Framework Mapping

This document maps Nexus platform components to enterprise cybersecurity frameworks and data protection regulations.

## Framework Mapping Table

| Nexus Component | Control Category | Framework Mapping | Implementation |
|-----------------|-----------------|-------------------|----------------|
| SOPS + KMS | Encryption at Rest | Data Protection | All secrets encrypted with AWS KMS before Git commit |
| External Secrets Operator | Secret Management | Data Protection | No plaintext secrets in cluster; synced from AWS SM |
| Kyverno Image Signature Verification | Software Integrity | Cybersecurity Framework | Cosign KMS verification enforced at admission |
| Kyverno Registry Restriction | Supply Chain Security | Cybersecurity Framework | Only private ECR images allowed |
| Kyverno Non-Root Enforcement | Least Privilege | Cybersecurity Framework | All containers run as non-root with dropped capabilities |
| Falco Runtime Detection | Intrusion Detection | Cybersecurity Framework | eBPF-based monitoring with custom rules |
| CloudTrail + S3 Object Lock | Audit Logging | Data Protection | 7-year immutable audit trail |
| VPC Flow Logs | Network Monitoring | Cybersecurity Framework | All traffic logged to S3 with compliance retention |
| GuardDuty + Security Hub | Threat Detection | Cybersecurity Framework | Automated threat intelligence and findings aggregation |
| Drift Detection | Change Control | Cybersecurity Framework | 15-minute detection of manual console changes |
| Atlantis PR-Based Apply | Segregation of Duties | Cybersecurity Framework | No direct terraform apply; all changes via PR |
| Conftest + OPA Policies | Policy Enforcement | Cybersecurity Framework | Terraform plans validated before apply |
| SBOM Generation | Asset Inventory | Cybersecurity Framework | CycloneDX SBOMs generated and signed per build |
| Dependency-Track | Vulnerability Management | Cybersecurity Framework | Continuous tracking of third-party component risks |
| Break-Glass Procedures | Emergency Access | Cybersecurity Framework | 4-eyes approval with full audit logging |
| MFA Delete on State Buckets | Data Protection | Data Protection | Prevents accidental or malicious state deletion |

## Evidence Collection

All evidence is automatically generated and stored:
- **CloudTrail logs**: S3 bucket with Object Lock COMPLIANCE mode
- **Policy violations**: Kyverno policy reports in S3
- **Scan results**: Trivy SARIF reports in GitHub Security tab
- **SBOMs**: Signed CycloneDX files in ECR and S3
- **Deployment records**: ArgoCD sync history in-cluster
- **Cost allocation**: Kubecost reports per team/namespace
