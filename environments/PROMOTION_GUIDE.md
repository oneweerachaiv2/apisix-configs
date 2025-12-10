# Environment Promotion Guide for APISIX API Versioning

## Overview

This guide explains how to version control and promote APISIX gateway resources across environments:
**DEV → SIT → UAT → PRODUCTION**

## Directory Structure

```
api-versioning/environments/
├── base/                      # Shared configurations
│   ├── kustomization.yaml
│   ├── routes.yaml
│   └── upstreams.yaml
├── dev/                       # Development overlay
│   └── kustomization.yaml
├── sit/                       # System Integration Testing overlay
│   ├── kustomization.yaml
│   └── rate-limit-plugin.yaml
├── uat/                       # User Acceptance Testing overlay
│   ├── kustomization.yaml
│   ├── rate-limit-plugin.yaml
│   └── auth-plugin.yaml
├── prod/                      # Production overlay
│   ├── kustomization.yaml
│   ├── rate-limit-plugin.yaml
│   ├── auth-plugin.yaml
│   └── monitoring-plugin.yaml
└── argocd-applicationset.yaml # GitOps deployment
```

## Environment Comparison

| Setting | DEV | SIT | UAT | PROD |
|---------|-----|-----|-----|------|
| Rate Limiting | ❌ Off | 1000/min | 500/min | 100/min |
| Authentication | ❌ Off | ❌ Off | ✅ JWT | ✅ JWT + IP |
| Monitoring | Basic | Basic | Enhanced | Full |
| Log Level | debug | info | info | warn |
| Redis (distributed) | ❌ | ❌ | ❌ | ✅ |

## Promotion Workflow

### Option 1: GitOps with ArgoCD (Recommended)

```bash
# 1. Make changes in base/ or environment overlay
git checkout -b feature/api-v4-users

# 2. Test locally with dev overlay
kustomize build environments/dev | kubectl apply --dry-run=client -f -

# 3. Commit and create PR
git add .
git commit -m "feat: Add API V4 users endpoint"
git push origin feature/api-v4-users

# 4. After PR merge, ArgoCD auto-syncs to DEV
# 5. Promote to SIT by tagging or branch strategy
git tag sit-release-v1.2.0
git push origin sit-release-v1.2.0

# 6. After SIT testing, promote to UAT
git tag uat-release-v1.2.0
git push origin uat-release-v1.2.0

# 7. After UAT approval, promote to PROD
git tag prod-release-v1.2.0
git push origin prod-release-v1.2.0
```

### Option 2: Manual Kustomize Deployment

```bash
# Deploy to DEV
kustomize build environments/dev | kubectl apply -f -

# After DEV testing, deploy to SIT
kustomize build environments/sit | kubectl apply -f -

# After SIT testing, deploy to UAT
kustomize build environments/uat | kubectl apply -f -

# After UAT approval, deploy to PROD
kustomize build environments/prod | kubectl apply -f -
```

### Option 3: Helm with Values Files

```bash
# Deploy to each environment with different values
helm upgrade --install apisix-routes ./chart \
  -f values-dev.yaml \
  -n apisix-dev

helm upgrade --install apisix-routes ./chart \
  -f values-prod.yaml \
  -n apisix-prod
```

## Branch Strategy

```
main (production)
  ├── release/uat     ← UAT environment
  ├── release/sit     ← SIT environment  
  └── develop         ← DEV environment
       └── feature/*  ← Feature branches
```

## Rollback Procedure

```bash
# Using ArgoCD
argocd app rollback apisix-api-versioning-prod

# Using kubectl
kubectl rollout undo deployment/apisix -n apisix-prod

# Using Git revert
git revert HEAD
git push origin main
```

## Pre-Promotion Checklist

- [ ] All tests pass in current environment
- [ ] API documentation updated
- [ ] Changelog updated
- [ ] Rate limits appropriate for target environment
- [ ] Authentication configured correctly
- [ ] Monitoring dashboards ready
- [ ] Rollback plan documented
- [ ] Stakeholder approval obtained (for UAT/PROD)

