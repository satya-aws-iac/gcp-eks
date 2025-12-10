# GKE Terraform CI/CD Workflow Guide

## Branch Strategy

```
feature/* → stage → main
    ↓         ↓      ↓
  (dev)   (plan)  (apply)
```

### Branch Purposes

- **`feature/*`**: Development branches for new changes
- **`stage`**: Testing and validation - runs Terraform plan
- **`main`**: Production - automatically applies Terraform changes

## Workflow Overview

### 1. Making Changes (Feature Branch)

```bash
# Create feature branch
git checkout -b feature/add-new-nodepool

# Make your changes to terraform files
# Edit terraform/main.tf, variables.tf, etc.

# Commit changes
git add .
git commit -m "Add new node pool configuration"

# Push to GitHub
git push origin feature/add-new-nodepool
```

### 2. Testing in Stage

```bash
# Merge feature to stage
git checkout stage
git merge feature/add-new-nodepool
git push origin stage
```

**What happens automatically:**
- ✅ Terraform format check
- ✅ Terraform init
- ✅ Terraform validate
- ✅ Terraform plan
- ✅ Security scan
- ✅ Cost estimation
- ✅ Creates GitHub issue with plan output

**Review the plan:**
- Go to Actions tab → "Stage Branch Validation"
- Check the workflow summary
- Review the created GitHub issue
- Verify planned changes are correct

### 3. Promoting to Production

**Option A: Create Pull Request (Recommended)**

```bash
# Go to GitHub Actions → "Promote Stage to Main"
# Click "Run workflow"
# Type "promote" to confirm
# Select "Create PR instead of direct merge" = Yes
```

This creates a PR for team review before applying.

**Option B: Direct Merge**

```bash
# After reviewing stage plan
git checkout main
git merge stage
git push origin main
```

**What happens automatically:**
- ✅ Terraform plan
- ✅ Terraform apply (to GCP)
- ✅ Cluster verification
- ✅ Creates GitHub issue with results

## Workflows Explained

### 1. `terraform-plan.yml`
**Triggers:**
- Push to `stage` branch
- Pull requests to `main` or `stage`

**Actions:**
- Validates Terraform configuration
- Runs Terraform plan
- Posts plan to PR comments
- Creates GitHub issue with plan summary

### 2. `terraform-apply.yml`
**Triggers:**
- Push to `main` branch
- Manual trigger via workflow_dispatch

**Actions:**
- Runs Terraform plan
- Applies changes to GCP
- Verifies GKE cluster
- Creates success/failure issue

### 3. `stage-validation.yml`
**Triggers:**
- Push to `stage` branch
- Pull requests to `stage`

**Actions:**
- Complete validation suite
- Security scanning
- Cost estimation
- Detailed reporting

### 4. `promote-to-main.yml`
**Triggers:**
- Manual trigger only

**Actions:**
- Creates PR from stage to main
- Or directly merges (if selected)

## Common Scenarios

### Scenario 1: Add New Resources

```bash
# 1. Create feature branch
git checkout -b feature/add-monitoring

# 2. Edit Terraform files
# Add new resources in terraform/main.tf

# 3. Test in stage
git checkout stage
git merge feature/add-monitoring
git push origin stage

# 4. Wait for validation ⏳

# 5. Review plan in GitHub Issues

# 6. Promote to main if OK
# Use "Promote Stage to Main" workflow
```

### Scenario 2: Emergency Rollback

```bash
# Revert last commit on main
git checkout main
git revert HEAD
git push origin main

# This will trigger terraform apply with previous state
```

### Scenario 3: Test Multiple Changes

```bash
# You can push multiple times to stage
git checkout stage
git merge feature/change1
git push origin stage  # Run 1

# Review plan

git merge feature/change2
git push origin stage  # Run 2

# Review combined plan

# Then promote to main once satisfied
```

## GitHub Secrets Required

Configure these in: `Settings → Secrets and variables → Actions`

| Secret | Description | Example |
|--------|-------------|---------|
| `GCP_PROJECT_ID` | Your GCP project ID | `my-project-123` |
| `GCP_SA_KEY` | Service account JSON key | `{"type": "service_account"...}` |
| `GCP_REGION` | GCP region | `us-central1-a` |
| `GKE_CLUSTER_NAME` | Cluster name | `my-gke-cluster` |

## GitHub Environment Protection

Setup protection rules for `main`:
1. Go to `Settings → Environments → New environment`
2. Name: `production`
3. Add protection rules:
   - ✅ Required reviewers (1-2 people)
   - ✅ Wait timer: 5 minutes
   - ✅ Deployment branches: Only `main`

## Monitoring & Notifications

### GitHub Issues
- Automatically created for each stage plan
- Created on successful/failed applies
- Tagged with labels for easy filtering

### View Logs
```bash
# All workflow runs
https://github.com/YOUR_USERNAME/YOUR_REPO/actions

# Specific workflow
https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/terraform-apply.yml
```

## Best Practices

1. **Always test in stage first** - Never push directly to main
2. **Review plans carefully** - Check the GitHub issue created after stage push
3. **Use feature branches** - Keep changes isolated and organized
4. **Small, incremental changes** - Easier to review and rollback
5. **Meaningful commit messages** - Helps track what changed
6. **Tag releases** - Use git tags for major deployments

## Troubleshooting

### Plan fails in stage
1. Check workflow logs in Actions tab
2. Fix issues in feature branch
3. Merge to stage again

### Apply fails in main
1. GitHub issue will be created with error
2. Check workflow logs
3. Fix in new feature branch
4. Test in stage
5. Promote to main

### Permission errors
```bash
# Verify service account has required roles
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:github-actions-gke@*"
```

## Commands Cheat Sheet

```bash
# Check current branch
git branch

# Create and switch to feature branch
git checkout -b feature/my-change

# Merge feature to stage for testing
git checkout stage
git merge feature/my-change
git push origin stage

# After reviewing stage plan, promote to main
git checkout main
git merge stage
git push origin main

# View changes between branches
git diff stage main

# View recent commits
git log --oneline -10
```

## Getting Help

- Review workflow runs in Actions tab
- Check GitHub issues for plan outputs
- Review this documentation
- Check Terraform documentation: https://registry.terraform.io/providers/hashicorp/google/latest/docs