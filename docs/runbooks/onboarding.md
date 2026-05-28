# Team Onboarding Runbook

## Adding a New Team

1. **Create ApplicationSet** in `gitops/argocd-apps/teams/`
2. **Create namespace** via Golden Path Factory
3. **Grant repo access** in GitHub
4. **Provision SOPS key** for team secrets
5. **Set up Kubecost allocation** for cost tracking

## Step-by-Step

### 1. ApplicationSet

```yaml
# gitops/argocd-apps/teams/team-data-application-set.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: team-data-services
spec:
  generators:
    - git:
        repoURL: https://github.com/example-org/nexus-platform.git
        directories:
          - path: gitops/teams/data/*
  template:
    metadata:
      name: "{{path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/example-org/nexus-platform.git
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}"
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
```

### 2. Golden Path

In Backstage, click **"New Microservice"** → Select team → Auto-provision:
- Namespace
- ResourceQuota
- LimitRange
- NetworkPolicy
- RBAC
- IRSA role

### 3. SOPS Key

```bash
# Generate team-specific KMS key
aws kms create-key --description "SOPS key for team-data"

# Update .sops.yaml with new creation rule
```

### 4. Kubecost Allocation

Add team to `terraform.tfvars`:
```hcl
cost_centers = {
  team-data = "data-platform"
}
```

## Verification

```bash
kubectl get namespaces | grep team-data
kubectl auth can-i --list --as=system:serviceaccount:team-data:default
```
