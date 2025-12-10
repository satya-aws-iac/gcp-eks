# Complete Guide: Standard GKE Cluster with GitHub Actions CI/CD

## 📋 Table of Contents

1. [Current Setup Overview](#current-setup-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Existing Configuration](#existing-configuration)
5. [Daily Operations](#daily-operations)
6. [Workflow Details](#workflow-details)
7. [Managing Your Cluster](#managing-your-cluster)
8. [Troubleshooting](#troubleshooting)
9. [Cost Management](#cost-management)
10. [Security & Best Practices](#security--best-practices)

---

## Current Setup Overview

### What You Have

✅ **Standard GKE Cluster** (Not Autopilot)
- **Cluster Name**: `my-gke-cluster`
- **Location**: `us-central1-a` (single zone)
- **Nodes**: 2 nodes (can autoscale 1-3)
- **Machine Type**: `e2-small` (2 vCPU, 2GB RAM)
- **Disk**: 30GB standard disk per node
- **Node Type**: Preemptible (80% cost savings)

✅ **GitHub Actions CI/CD**
- OIDC authentication (secure, no service account keys)
- Stage → Main workflow for safe deployments
- Automated plan on push to `stage`
- Automated apply on push to `main`
- Health checks every 6 hours

✅ **Project Details**
- **Project ID**: `satya-k8-poc`
- **Region**: `us-central1`
- **Zone**: `us-central1-a`
- **Repository**: `satya-aws-iac/gcp-eks`
- **Terraform State**: GCS bucket `satya-k8-poc-terraform-state`

### Key Features

🔐 **Security**
- OIDC Workload Identity Federation (no keys stored)
- Service account with least privilege
- Workload Identity enabled on cluster

🚀 **Automation**
- Push to `stage` → Terraform plan runs
- Push to `main` → Infrastructure deployed
- Scheduled health checks
- One-click cluster destruction

💰 **Cost Optimized**
- Preemptible nodes (80% cheaper)
- Single zone deployment
- Small machine types (e2-small)
- Autoscaling (1-3 nodes)

---

## Architecture

### Infrastructure Flow

```
┌─────────────────────────────────────────────────────┐
│                  GitHub Repository                   │
│              satya-aws-iac/gcp-eks                  │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Push to stage
                 ▼
┌─────────────────────────────────────────────────────┐
│            Terraform Plan Workflow                   │
│  • Validates configuration                          │
│  • Runs terraform plan                              │
│  • Creates GitHub issue with plan                   │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Review & Approve
                 │ Merge to main
                 ▼
┌─────────────────────────────────────────────────────┐
│           Terraform Apply Workflow                   │
│  • Applies infrastructure changes                   │
│  • Creates/updates GKE cluster                      │
│  • Verifies cluster health                          │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│              GCP Project: satya-k8-poc              │
│  ┌──────────────────────────────────────────────┐  │
│  │         GKE Cluster: my-gke-cluster          │  │
│  │  Location: us-central1-a                     │  │
│  │  Nodes: 2 x e2-small (preemptible)          │  │
│  │  Network: VPC with secondary ranges          │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Network Architecture

```
VPC: my-gke-cluster-vpc
├── Subnet: my-gke-cluster-subnet (10.0.0.0/24)
│   ├── Primary: 10.0.0.0/24 (node IPs)
│   ├── Pods: 10.1.0.0/16 (pod IPs)
│   └── Services: 10.2.0.0/16 (service IPs)
└── Node Pool: my-gke-cluster-node-pool
    ├── Node 1: e2-small (preemptible)
    └── Node 2: e2-small (preemptible)
```

---

## Prerequisites

### Access Required

✅ **GCP Access**
- Project: `satya-k8-poc`
- Role: Owner or Editor
- gcloud CLI configured

✅ **GitHub Access**
- Repository: `satya-aws-iac/gcp-eks`
- Admin access to manage workflows

✅ **Local Tools**
```powershell
# Verify installations
gcloud --version    # Google Cloud SDK
kubectl version     # Kubernetes CLI
git --version       # Git
terraform --version # (optional) Terraform CLI
```

### GitHub Secrets (Already Configured)

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/.../workloadIdentityPools/...` | OIDC authentication |
| `GCP_SERVICE_ACCOUNT` | `github-actions-gke@satya-k8-poc.iam.gserviceaccount.com` | Service account email |
| `GCP_PROJECT_ID` | `satya-k8-poc` | GCP project identifier |
| `GCP_REGION` | `us-central1` | GCP region |
| `GKE_CLUSTER_NAME` | `my-gke-cluster` | Cluster name |

---

## Existing Configuration

### Terraform Files

**`terraform/main.tf`**
- Defines VPC network with secondary IP ranges
- Creates standard GKE cluster (not Autopilot)
- Configures node pool with 2 e2-small nodes
- Sets up service account for nodes
- Enables Workload Identity

**`terraform/variables.tf`**
```hcl
project_id     # GCP project ID
region         # us-central1
zone           # us-central1-a (single zone)
cluster_name   # my-gke-cluster
environment    # dev
```

**`terraform/outputs.tf`**
- Cluster name, endpoint, CA certificate
- VPC and subnet names
- Node pool details
- Zone information

**`terraform/backend.tf`**
- GCS backend for Terraform state
- Bucket: `satya-k8-poc-terraform-state`
- Prefix: `terraform/gke/state`

### Workflow Files

**`.github/workflows/terraform-plan.yml`**
- Triggers: Push to `stage` branch or PRs to `main`/`stage`
- Actions: Format check, init, validate, plan
- Outputs: GitHub issue with plan details

**`.github/workflows/terraform-apply.yml`**
- Triggers: Push to `main` branch
- Actions: Plan, apply, get cluster credentials
- Note: Has ordering issue (gets credentials before cluster exists)

**`.github/workflows/stage-validation.yml`**
- Triggers: Push to `stage` or PRs to `stage`
- Actions: Complete validation with security scan
- Outputs: Detailed validation report

**`.github/workflows/cluster-health.yml`**
- Triggers: Every 6 hours or manual
- Actions: Checks cluster, nodes, pods, services
- Zone: Hardcoded to `us-central1-a`

**`.github/workflows/terraform-destroy.yml`**
- Triggers: Manual only (requires "destroy" confirmation)
- Actions: Plans and applies destroy operation
- Creates GitHub issue on completion

**`.github/workflows/terraform-unlock.yml`**
- Triggers: Manual only
- Actions: Removes Terraform state lock
- Useful when workflow fails mid-execution

**`.github/workflows/promote-to-main.yml`**
- Triggers: Manual only
- Actions: Creates PR from `stage` to `main` or direct merge
- Requires "promote" confirmation

---

## Daily Operations

### Making Infrastructure Changes

#### Step 1: Create Feature Branch

```powershell
# Clone repository (if not already)
git clone https://github.com/satya-aws-iac/gcp-eks.git
cd gcp-eks

# Create feature branch
git checkout -b feature/add-node-labels
```

#### Step 2: Make Changes

```powershell
# Edit Terraform files
notepad terraform/main.tf

# Example: Add node labels
# In node_config block:
labels = {
  env = var.environment
  team = "platform"
  app = "my-app"
}
```

#### Step 3: Test in Stage

```powershell
# Commit changes
git add terraform/
git commit -m "Add node labels for better organization"

# Push to feature branch
git push origin feature/add-node-labels

# Merge to stage for testing
git checkout stage
git merge feature/add-node-labels
git push origin stage
```

#### Step 4: Review Plan

1. Go to: https://github.com/satya-aws-iac/gcp-eks/actions
2. Click on "Terraform Plan" or "Stage Branch Validation"
3. Review the workflow output
4. Check GitHub Issues for detailed plan

#### Step 5: Deploy to Production

```powershell
# If plan looks good, merge to main
git checkout main
git merge stage
git push origin main

# Or use "Promote Stage to Main" workflow:
# Actions → Promote Stage to Main → Run workflow → Type "promote"
```

### Accessing Your Cluster

```powershell
# Get cluster credentials
gcloud container clusters get-credentials my-gke-cluster `
    --zone us-central1-a `
    --project satya-k8-poc

# Verify access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Deploying Applications

```bash
# Example: Deploy nginx
kubectl create deployment nginx --image=nginx:latest --replicas=2

# Expose as LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get external IP
kubectl get svc nginx
# Wait for EXTERNAL-IP to appear (takes 2-3 minutes)

# Test
curl http://EXTERNAL-IP
```

### Scaling Your Cluster

#### Scale Nodes

```bash
# Scale to 3 nodes
gcloud container clusters resize my-gke-cluster \
    --num-nodes=3 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool

# Scale down to 1 node (save costs)
gcloud container clusters resize my-gke-cluster \
    --num-nodes=1 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool
```

#### Scale Deployments

```bash
# Scale deployment
kubectl scale deployment nginx --replicas=5

# Check status
kubectl get pods
```

### Monitoring Cluster Health

```powershell
# Manual health check via workflow
# Go to: Actions → GKE Cluster Health Check → Run workflow

# Or check manually
kubectl get nodes -o wide
kubectl top nodes
kubectl get pods --all-namespaces
```

---

## Workflow Details

### Workflow: terraform-apply.yml (⚠️ Has Issue)

**Current Issue:**
The workflow tries to get cluster credentials BEFORE applying Terraform, which will fail on first run.

**Current Order (Incorrect):**
```yaml
1. Checkout
2. Setup Terraform
3. Authenticate to GCP
4. Setup gcloud CLI
5. Terraform Init
6. Terraform Plan
7. Get GKE Credentials ❌ (cluster doesn't exist yet)
8. Terraform Apply
9. Get Cluster Info
```

**Correct Order Should Be:**
```yaml
1. Checkout
2. Setup Terraform
3. Authenticate to GCP
4. Setup gcloud CLI
5. Terraform Init
6. Terraform Plan
7. Terraform Apply
8. Get Cluster Info from Terraform Outputs
9. Get GKE Credentials ✅
10. Verify Cluster
```

### Fix for terraform-apply.yml

Replace the workflow with this corrected version:

```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve tfplan
  working-directory: ${{ env.WORKING_DIR }}

- name: Get Cluster Info from Terraform
  id: cluster_info
  run: |
    CLUSTER_ZONE=$(terraform output -raw zone)
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    echo "zone=${CLUSTER_ZONE}" >> $GITHUB_OUTPUT
    echo "name=${CLUSTER_NAME}" >> $GITHUB_OUTPUT
    echo "Cluster: ${CLUSTER_NAME} in zone ${CLUSTER_ZONE}"
  working-directory: ${{ env.WORKING_DIR }}

- name: Get GKE Credentials
  run: |
    gcloud container clusters get-credentials ${{ steps.cluster_info.outputs.name }} \
      --zone ${{ steps.cluster_info.outputs.zone }} \
      --project ${{ secrets.GCP_PROJECT_ID }}

- name: Verify Cluster
  run: |
    echo "=== Cluster Info ==="
    kubectl cluster-info
    
    echo -e "\n=== Nodes ==="
    kubectl get nodes -o wide
    
    echo -e "\n=== Namespaces ==="
    kubectl get namespaces
```

---

## Managing Your Cluster

### View Cluster Resources

```bash
# All resources
kubectl get all --all-namespaces

# Nodes
kubectl get nodes -o wide

# Pods
kubectl get pods --all-namespaces

# Services
kubectl get services --all-namespaces

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Cluster Operations

#### Upgrade Cluster

```bash
# Check available versions
gcloud container get-server-config --zone=us-central1-a

# Upgrade control plane
gcloud container clusters upgrade my-gke-cluster \
    --zone=us-central1-a \
    --master \
    --cluster-version=VERSION

# Upgrade nodes
gcloud container clusters upgrade my-gke-cluster \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool
```

#### Node Pool Operations

```bash
# Describe node pool
gcloud container node-pools describe my-gke-cluster-node-pool \
    --cluster=my-gke-cluster \
    --zone=us-central1-a

# Drain node (move pods off)
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data

# Cordon node (prevent new pods)
kubectl cordon NODE_NAME

# Uncordon node
kubectl uncordon NODE_NAME
```

### Destroy Cluster

```powershell
# Via GitHub Actions (Recommended)
# 1. Go to: Actions → Terraform Destroy
# 2. Click "Run workflow"
# 3. Type "destroy" to confirm
# 4. Wait for completion

# Manually via Terraform
cd terraform
terraform destroy `
    -var="project_id=satya-k8-poc" `
    -var="region=us-central1" `
    -var="zone=us-central1-a" `
    -var="cluster_name=my-gke-cluster"
```

---

## Troubleshooting

### Common Issues

#### Issue 1: terraform-apply.yml Fails on First Run

**Error:**
```
Error: getting credentials: Get "https://...": cluster not found
```

**Cause:** Workflow tries to get credentials before cluster is created

**Fix:** Update workflow as shown in "Fix for terraform-apply.yml" section above

#### Issue 2: Preemptible Node Terminated

**Symptom:** Node suddenly disappears, pods rescheduled

**Explanation:** Preemptible nodes can be terminated by GCP with 30 seconds notice

**Solution:**
- This is normal behavior for preemptible nodes
- Pods will automatically reschedule to other nodes
- Use PodDisruptionBudgets for critical apps:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-app
```

#### Issue 3: Out of Resources

**Error:**
```
0/2 nodes available: insufficient memory/cpu
```

**Solutions:**

1. **Scale up nodes:**
```bash
gcloud container clusters resize my-gke-cluster \
    --num-nodes=3 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool
```

2. **Reduce pod resource requests:**
```yaml
resources:
  requests:
    memory: "128Mi"  # Reduce from higher value
    cpu: "100m"      # Reduce from higher value
```

3. **Delete unused workloads:**
```bash
kubectl delete deployment UNUSED_APP
```

#### Issue 4: Terraform State Locked

**Error:**
```
Error: Error acquiring the state lock
```

**Solution:**
```powershell
# Use unlock workflow
# Go to: Actions → Terraform Unlock State → Run workflow

# Or manually
cd terraform
terraform force-unlock LOCK_ID
```

#### Issue 5: OIDC Authentication Failed

**Error:**
```
failed to generate Google Cloud access token
```

**Solution:**
```powershell
# Verify Workload Identity Provider
gcloud iam workload-identity-pools describe github-pool \
    --location=global \
    --project=satya-k8-poc

# Verify service account binding
gcloud iam service-accounts get-iam-policy \
    github-actions-gke@satya-k8-poc.iam.gserviceaccount.com
```

### Debug Commands

```bash
# Check cluster status
gcloud container clusters describe my-gke-cluster \
    --zone=us-central1-a

# Check node status
kubectl describe node NODE_NAME

# Check pod events
kubectl get events --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs POD_NAME

# Check workflow logs
# Go to: https://github.com/satya-aws-iac/gcp-eks/actions
```

---

## Cost Management

### Current Monthly Costs

**Breakdown:**
```
GKE Management Fee:    $73.00/month ($0.10/hour)
2x e2-small nodes:     ~$15.00/month (preemptible)
2x 30GB disks:         ~$6.00/month (standard)
Network egress:        ~$2.00/month (varies)
─────────────────────
Total:                 ~$96.00/month
```

### Cost Optimization

#### 1. Scale Down When Not in Use

```bash
# Nights/weekends, scale to 1 node
gcloud container clusters resize my-gke-cluster \
    --num-nodes=1 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool

# Savings: ~$7/month per node removed
```

#### 2. Delete Unused LoadBalancers

```bash
# List LoadBalancers (cost $18/month each!)
kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# Delete unused
kubectl delete svc UNUSED_LB_SERVICE
```

#### 3. Clean Up Unused Persistent Volumes

```bash
# List PVs
kubectl get pv

# Delete unused
kubectl delete pvc UNUSED_PVC
```

#### 4. Monitor Costs

```powershell
# View current costs in GCP Console
https://console.cloud.google.com/billing/

# Set up budget alerts
# Go to: Billing → Budgets & alerts
# Create alert at $100/month
```

#### 5. Destroy When Not Needed

```bash
# Delete entire cluster to stop all costs
# Actions → Terraform Destroy → Type "destroy"
# Saves ~$96/month
```

---

## Security & Best Practices

### Security Features (Already Enabled)

✅ **OIDC Authentication** - No service account keys stored
✅ **Workload Identity** - Pods can assume GCP service accounts
✅ **Private IPs** - Nodes use private IP addresses
✅ **Minimal IAM** - Service account has only required permissions
✅ **Automated Updates** - Nodes auto-repair and auto-upgrade

### Best Practices

#### 1. Resource Limits

Always set resource limits:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

#### 2. Use Namespaces

```bash
# Create namespace
kubectl create namespace production

# Deploy to namespace
kubectl create deployment nginx --image=nginx -n production
```

#### 3. Use Secrets for Sensitive Data

```bash
# Create secret
kubectl create secret generic db-password \
    --from-literal=password=mypassword

# Use in pod
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-password
        key: password
```

#### 4. Regular Backups

```bash
# Backup deployments
kubectl get deployments --all-namespaces -o yaml > deployments-backup.yaml

# Backup services
kubectl get services --all-namespaces -o yaml > services-backup.yaml
```

#### 5. Monitor & Alert

```bash
# Enable GKE monitoring
gcloud container clusters update my-gke-cluster \
    --enable-cloud-monitoring \
    --zone=us-central1-a
```

---

## Quick Reference

### Important URLs

- **GCP Console**: https://console.cloud.google.com
- **GKE Clusters**: https://console.cloud.google.com/kubernetes/list?project=satya-k8-poc
- **GitHub Repo**: https://github.com/satya-aws-iac/gcp-eks
- **GitHub Actions**: https://github.com/satya-aws-iac/gcp-eks/actions
- **Terraform State**: https://console.cloud.google.com/storage/browser/satya-k8-poc-terraform-state

### Essential Commands

```bash
# Get cluster access
gcloud container clusters get-credentials my-gke-cluster \
    --zone us-central1-a --project satya-k8-poc

# View resources
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces

# Deploy app
kubectl create deployment my-app --image=my-image
kubectl expose deployment my-app --port=80 --type=LoadBalancer

# Scale cluster
gcloud container clusters resize my-gke-cluster \
    --num-nodes=3 --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool

# Destroy cluster
# Actions → Terraform Destroy → Type "destroy"
```

### Workflow Triggers

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| terraform-plan.yml | Push to `stage` | Plan infrastructure changes |
| terraform-apply.yml | Push to `main` | Apply infrastructure changes |
| stage-validation.yml | Push to `stage` | Full validation suite |
| cluster-health.yml | Every 6 hours | Monitor cluster health |
| terraform-destroy.yml | Manual | Destroy cluster |
| terraform-unlock.yml | Manual | Unlock Terraform state |
| promote-to-main.yml | Manual | Promote stage to main |

---

## Summary

### What You Have

✅ **Production-ready GKE cluster** with 2 nodes
✅ **Secure OIDC authentication** (no keys!)
✅ **Automated CI/CD** with GitHub Actions
✅ **Cost-optimized** ($96/month)
✅ **Fully documented** setup

### Next Steps

1. **Deploy your applications** to the cluster
2. **Set up monitoring** and alerting
3. **Configure CI/CD** for your apps
4. **Implement backup** strategy
5. **Add more environments** (prod, staging, dev)

### Getting Help

- **GitHub Issues**: Check for plan outputs and errors
- **Workflow Logs**: https://github.com/satya-aws-iac/gcp-eks/actions
- **GKE Docs**: https://cloud.google.com/kubernetes-engine/docs
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

---

**Documentation Version**: 2.0 - Updated for Standard GKE
**Last Updated**: December 2024
**Project**: satya-k8-poc
**Repository**: satya-aws-iac/gcp-eks