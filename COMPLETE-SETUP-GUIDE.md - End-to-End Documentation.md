# Complete Guide: GKE Cluster with GitHub Actions CI/CD

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Part 1: GCP Project Setup](#part-1-gcp-project-setup)
5. [Part 2: GitHub Repository Setup](#part-2-github-repository-setup)
6. [Part 3: OIDC Authentication Setup](#part-3-oidc-authentication-setup)
7. [Part 4: Terraform Configuration](#part-4-terraform-configuration)
8. [Part 5: GitHub Actions Workflows](#part-5-github-actions-workflows)
9. [Part 6: Testing & Deployment](#part-6-testing--deployment)
10. [Part 7: Daily Operations](#part-7-daily-operations)
11. [Troubleshooting](#troubleshooting)
12. [Cost Optimization](#cost-optimization)

---

## Overview

### What We're Building

A fully automated GKE (Google Kubernetes Engine) cluster deployment using:
- **Terraform** for Infrastructure as Code
- **GitHub Actions** for CI/CD automation
- **OIDC** for secure authentication (no service account keys!)
- **GKE Autopilot** for cost-optimized Kubernetes
- **Stage → Main workflow** for safe deployments

### Key Features

✅ **Secure**: OIDC authentication, no long-lived credentials
✅ **Automated**: Push to deploy, no manual intervention
✅ **Safe**: Test in stage before production
✅ **Cost-Optimized**: GKE Autopilot, pay-per-pod model
✅ **GitOps**: Infrastructure defined in code
✅ **Auditable**: Full history in Git, workflow logs in GitHub

### Final Architecture

```
┌─────────────┐
│   GitHub    │
│ Repository  │
└──────┬──────┘
       │
       │ (Push to stage)
       ▼
┌─────────────┐
│  Terraform  │
│    Plan     │ ──► GitHub Issue (Review)
└──────┬──────┘
       │
       │ (Merge to main)
       ▼
┌─────────────┐      ┌──────────────┐
│  Terraform  │ ───► │  GCP Project │
│    Apply    │      │  GKE Cluster │
└─────────────┘      └──────────────┘
```

---

## Prerequisites

### Required Tools

Install these on your local machine:

```powershell
# PowerShell (Windows)
# Install gcloud CLI
# Download from: https://cloud.google.com/sdk/docs/install

# Verify installation
gcloud --version

# Install Git
# Download from: https://git-scm.com/downloads
git --version

# Install Terraform (optional, for local testing)
# Download from: https://www.terraform.io/downloads
terraform --version
```

### Required Accounts

1. **Google Cloud Account**
   - Active billing account
   - Project with billing enabled
   - Organization admin access (or project owner)

2. **GitHub Account**
   - Repository owner or admin access
   - Ability to manage secrets and workflows

### Required Permissions

**GCP Permissions:**
- Project Owner OR
- These specific roles:
  - Compute Admin
  - Kubernetes Engine Admin
  - Service Account Admin
  - Storage Admin
  - Workload Identity Pool Admin

**GitHub Permissions:**
- Repository admin access
- Ability to manage Actions and Secrets

---

## Part 1: GCP Project Setup

### Step 1.1: Create GCP Project

```powershell
# Login to GCP
gcloud auth login

# Set your variables
$PROJECT_ID = "your-project-id"  # Change this!
$REGION = "us-central1-a"
$BILLING_ACCOUNT = "YOUR-BILLING-ACCOUNT-ID"

# Create project
gcloud projects create $PROJECT_ID `
    --name="GKE GitHub Actions Project"

# Link billing account
gcloud billing projects link $PROJECT_ID `
    --billing-account=$BILLING_ACCOUNT

# Set as default project
gcloud config set project $PROJECT_ID
```

### Step 1.2: Enable Required APIs

```powershell
# Enable all required GCP APIs
$apis = @(
    "container.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor Yellow
    gcloud services enable $api --project=$PROJECT_ID
}

Write-Host "✅ All APIs enabled" -ForegroundColor Green
```

### Step 1.3: Create GCS Bucket for Terraform State

```powershell
# Create bucket for Terraform state
$BUCKET_NAME = "${PROJECT_ID}-terraform-state"

gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME

# Enable versioning for safety
gsutil versioning set on gs://$BUCKET_NAME

Write-Host "✅ Terraform state bucket created: $BUCKET_NAME" -ForegroundColor Green
```

### Step 1.4: Create Service Account

```powershell
# Create service account for GitHub Actions
$SA_NAME = "github-actions-gke"
$SA_EMAIL = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME `
    --display-name="GitHub Actions GKE Service Account" `
    --project=$PROJECT_ID

Write-Host "✅ Service account created: $SA_EMAIL" -ForegroundColor Green
```

### Step 1.5: Grant IAM Permissions

```powershell
# Grant necessary roles to service account
$roles = @(
    "roles/container.admin",
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin"
)

foreach ($role in $roles) {
    Write-Host "Granting $role..." -ForegroundColor Yellow
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="serviceAccount:${SA_EMAIL}" `
        --role=$role
}

Write-Host "✅ All permissions granted" -ForegroundColor Green
```

---

## Part 2: GitHub Repository Setup

### Step 2.1: Create Repository

```powershell
# Option 1: Create via GitHub Web UI
# Go to: https://github.com/new
# Name: gke-infrastructure (or your choice)
# Visibility: Private (recommended)
# Initialize with README: Yes

# Option 2: Create via CLI (if gh CLI installed)
gh repo create gke-infrastructure --private --clone
```

### Step 2.2: Clone Repository Locally

```powershell
# Clone your repository
git clone https://github.com/YOUR_USERNAME/gke-infrastructure.git
cd gke-infrastructure

# Create branch structure
git checkout -b stage
git push -u origin stage

git checkout -b main
git push -u origin main

git checkout main
```

### Step 2.3: Create Directory Structure

```powershell
# Create directories
New-Item -Path "terraform" -ItemType Directory
New-Item -Path ".github/workflows" -ItemType Directory

# Verify structure
tree /F
```

Expected structure:
```
gke-infrastructure/
├── .github/
│   └── workflows/
├── terraform/
├── .gitignore
└── README.md
```

---

## Part 3: OIDC Authentication Setup

### Step 3.1: Get Project Number

```powershell
# Get your project number (needed for OIDC)
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
Write-Host "Project Number: $PROJECT_NUMBER" -ForegroundColor Cyan
```

### Step 3.2: Create Workload Identity Pool

```powershell
# Create Workload Identity Pool
$POOL_NAME = "github-actions-pool"

gcloud iam workload-identity-pools create $POOL_NAME `
    --project=$PROJECT_ID `
    --location="global" `
    --display-name="GitHub Actions Pool"

Write-Host "✅ Workload Identity Pool created" -ForegroundColor Green
```

### Step 3.3: Create OIDC Provider

```powershell
# Set your GitHub details
$GITHUB_ORG = "your-github-username"  # Change this!
$GITHUB_REPO = "gke-infrastructure"    # Change if different

# Create OIDC Provider
$PROVIDER_NAME = "github-actions-provider"

gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME `
    --project=$PROJECT_ID `
    --location="global" `
    --workload-identity-pool=$POOL_NAME `
    --display-name="GitHub Actions Provider" `
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" `
    --attribute-condition="assertion.repository_owner=='$GITHUB_ORG'" `
    --issuer-uri="https://token.actions.githubusercontent.com"

Write-Host "✅ OIDC Provider created" -ForegroundColor Green
```

### Step 3.4: Configure Workload Identity Binding

```powershell
# Allow GitHub Actions to impersonate service account
$WORKLOAD_IDENTITY_PRINCIPAL = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_ORG/$GITHUB_REPO"

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
    --project=$PROJECT_ID `
    --role="roles/iam.workloadIdentityUser" `
    --member="$WORKLOAD_IDENTITY_PRINCIPAL"

Write-Host "✅ Workload Identity binding created" -ForegroundColor Green
```

### Step 3.5: Get Configuration Values for GitHub

```powershell
# Get the Workload Identity Provider resource name
$WORKLOAD_IDENTITY_PROVIDER = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/providers/$PROVIDER_NAME"

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "GitHub Secrets Configuration" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nCopy these values to GitHub Secrets:" -ForegroundColor Yellow
Write-Host "`n1. GCP_WORKLOAD_IDENTITY_PROVIDER" -ForegroundColor White
Write-Host "   Value: $WORKLOAD_IDENTITY_PROVIDER" -ForegroundColor Gray
Write-Host "`n2. GCP_SERVICE_ACCOUNT" -ForegroundColor White
Write-Host "   Value: $SA_EMAIL" -ForegroundColor Gray
Write-Host "`n3. GCP_PROJECT_ID" -ForegroundColor White
Write-Host "   Value: $PROJECT_ID" -ForegroundColor Gray
Write-Host "`n4. GCP_REGION" -ForegroundColor White
Write-Host "   Value: $REGION" -ForegroundColor Gray
Write-Host "`n5. GKE_CLUSTER_NAME" -ForegroundColor White
Write-Host "   Value: my-gke-cluster" -ForegroundColor Gray
Write-Host "`n════════════════════════════════════════════" -ForegroundColor Cyan

# Copy provider to clipboard
$WORKLOAD_IDENTITY_PROVIDER | Set-Clipboard
Write-Host "`n✅ GCP_WORKLOAD_IDENTITY_PROVIDER copied to clipboard!" -ForegroundColor Green
```

### Step 3.6: Add Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to: **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add each secret:

| Secret Name | Value |
|-------------|-------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | (from Step 3.5) |
| `GCP_SERVICE_ACCOUNT` | `github-actions-gke@PROJECT_ID.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | Your project ID |
| `GCP_REGION` | `us-central1-a` |
| `GKE_CLUSTER_NAME` | `my-gke-cluster` |

---

## Part 4: Terraform Configuration

### Step 4.1: Create backend.tf

```powershell
cd terraform

# Create backend.tf
@"
terraform {
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "terraform/gke/state"
  }
}
"@ | Out-File -FilePath backend.tf -Encoding UTF8
```

### Step 4.2: Create variables.tf

```powershell
# Create variables.tf
@"
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "my-gke-cluster"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}
"@ | Out-File -FilePath variables.tf -Encoding UTF8
```

### Step 4.3: Create main.tf (GKE Autopilot)

```powershell
# Create main.tf
@"
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "`${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "`${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# GKE Autopilot Cluster
resource "google_container_cluster" "autopilot" {
  name                = var.cluster_name
  location            = var.region
  deletion_protection = false

  # Enable Autopilot
  enable_autopilot = true

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}
"@ | Out-File -FilePath main.tf -Encoding UTF8
```

### Step 4.4: Create outputs.tf

```powershell
# Create outputs.tf
@"
output "cluster_name" {
  description = "GKE Autopilot cluster name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "vpc_name" {
  description = "VPC name"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.subnet.name
}
"@ | Out-File -FilePath outputs.tf -Encoding UTF8
```

---

## Part 5: GitHub Actions Workflows

### Step 5.1: Create terraform-plan.yml

```powershell
cd ../.github/workflows

# Create terraform-plan.yml
# (Copy content from your terraform-plan.yml file)
```

### Step 5.2: Create terraform-apply.yml

```powershell
# Create terraform-apply.yml
# (Copy content from your terraform-apply.yml file)
```

### Step 5.3: Create stage-validation.yml

```powershell
# Create stage-validation.yml
# (Copy content from your stage-validation.yml file)
```

### Step 5.4: Create Additional Workflows

Create these additional workflow files:
- `cluster-health.yml` - Periodic health checks
- `terraform-destroy.yml` - Safe cluster deletion
- `promote-to-main.yml` - Automated promotion workflow

### Step 5.5: Create .gitignore

```powershell
cd ../..

# Create .gitignore
@"
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
tfplan

# GCP credentials
*.json
!package*.json

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
"@ | Out-File -FilePath .gitignore -Encoding UTF8
```

---

## Part 6: Testing & Deployment

### Step 6.1: Commit Initial Configuration

```powershell
# Add all files
git add .

# Commit
git commit -m "Initial GKE Terraform configuration with GitHub Actions"

# Push to main
git push origin main
```

### Step 6.2: Test in Stage Branch

```powershell
# Switch to stage branch
git checkout stage

# Merge main into stage
git merge main

# Push to trigger plan
git push origin stage
```

### Step 6.3: Review Terraform Plan

1. Go to your GitHub repository
2. Click **Actions** tab
3. Find the running "Terraform Plan" or "Stage Branch Validation" workflow
4. Review the workflow output
5. Check for any new GitHub Issues with plan details

### Step 6.4: Deploy to Production

If the plan looks good:

```powershell
# Option 1: Merge via GitHub UI
# Create PR: stage → main
# Review and merge

# Option 2: Merge locally
git checkout main
git merge stage
git push origin main
```

This will trigger the `terraform-apply.yml` workflow and create your GKE cluster!

### Step 6.5: Verify Cluster Creation

```powershell
# Wait for workflow to complete (5-15 minutes)
# Then verify cluster exists

gcloud container clusters list --project=$PROJECT_ID

# Get cluster credentials
gcloud container clusters get-credentials my-gke-cluster `
    --region $REGION `
    --project $PROJECT_ID

# Check cluster
kubectl cluster-info
kubectl get namespaces
```

---

## Part 7: Daily Operations

### Making Infrastructure Changes

```powershell
# 1. Create feature branch
git checkout -b feature/add-monitoring

# 2. Make changes to Terraform files
# Edit terraform/main.tf, variables.tf, etc.

# 3. Commit changes
git add .
git commit -m "Add monitoring configuration"
git push origin feature/add-monitoring

# 4. Merge to stage for testing
git checkout stage
git merge feature/add-monitoring
git push origin stage

# 5. Review plan in GitHub Actions/Issues

# 6. If approved, merge to main
git checkout main
git merge stage
git push origin main
```

### Monitoring Cluster Health

The cluster health workflow runs automatically every 6 hours. To run manually:

1. Go to **Actions** tab
2. Select **GKE Cluster Health Check**
3. Click **Run workflow**

### Destroying the Cluster

**⚠️ WARNING: This will delete everything!**

```powershell
# Option 1: Via GitHub Actions (Recommended)
# 1. Go to Actions → Terraform Destroy
# 2. Click "Run workflow"
# 3. Type "destroy" to confirm

# Option 2: Manually
cd terraform
terraform destroy -var="project_id=$PROJECT_ID" -var="region=$REGION"
```

---

## Troubleshooting

### Issue: "Permission Denied" Errors

**Solution:**
```powershell
# Verify service account permissions
gcloud projects get-iam-policy $PROJECT_ID `
    --flatten="bindings[].members" `
    --filter="bindings.members:github-actions-gke@*"

# Re-grant permissions if needed
gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/container.admin"
```

### Issue: "Quota Exceeded" Errors

**Solution:**
```powershell
# Check quotas
gcloud compute regions describe $REGION --format="yaml(quotas)"

# Request quota increase
# Go to: https://console.cloud.google.com/iam-admin/quotas
# Filter for the exceeded quota
# Click "Edit Quotas" → Request increase
```

### Issue: "State Lock" Errors

**Solution:**
```powershell
# Use the unlock workflow
# Go to Actions → Terraform Unlock State → Run workflow

# Or manually:
cd terraform
terraform force-unlock LOCK_ID
```

### Issue: "OIDC Authentication Failed"

**Solution:**
```powershell
# Verify Workload Identity Pool exists
gcloud iam workload-identity-pools describe github-actions-pool `
    --location=global `
    --project=$PROJECT_ID

# Verify provider exists
gcloud iam workload-identity-pools providers describe github-actions-provider `
    --location=global `
    --workload-identity-pool=github-actions-pool `
    --project=$PROJECT_ID

# Check IAM binding
gcloud iam service-accounts get-iam-policy $SA_EMAIL
```

---

## Cost Optimization

### Current Setup Costs

**GKE Autopilot:**
- **Base**: ~$10-30/month (pay per pod)
- **No management fee** (unlike standard GKE)
- **Auto-scaling**: Only pay for what you use

**Storage:**
- **GCS Bucket** (Terraform state): ~$0.02/month
- **Persistent Volumes**: ~$0.17/GB-month

**Network:**
- **Ingress**: Free
- **Egress**: ~$0.12/GB (first 1GB/month free)

### Total Estimated Cost: $10-40/month

### Tips to Reduce Costs

1. **Delete unused resources:**
```powershell
# List running workloads
kubectl get pods --all-namespaces

# Delete unused deployments
kubectl delete deployment UNUSED_DEPLOYMENT
```

2. **Set resource limits:**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

3. **Use preemptible nodes** (for non-critical workloads)

4. **Monitor costs:**
```powershell
# View current costs
gcloud billing accounts list
gcloud billing projects describe $PROJECT_ID
```

---

## Summary

### What You've Built

✅ **Secure GKE Cluster** with Autopilot mode
✅ **OIDC Authentication** (no service account keys)
✅ **Automated CI/CD** with GitHub Actions
✅ **Safe Deployment** via stage → main workflow
✅ **Infrastructure as Code** with Terraform
✅ **Cost Optimized** setup

### Key Commands Reference

```powershell
# Deploy changes
git checkout stage
git merge feature/my-change
git push origin stage  # Test
git checkout main
git merge stage
git push origin main   # Deploy

# Access cluster
gcloud container clusters get-credentials my-gke-cluster `
    --region us-central1-a --project $PROJECT_ID
kubectl get nodes

# View workflows
# Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/actions

# Destroy cluster
# Actions → Terraform Destroy → Run workflow → Type "destroy"
```

### Next Steps

1. **Deploy Applications**: Create Kubernetes manifests
2. **Add Monitoring**: Set up Cloud Monitoring
3. **Configure DNS**: Set up Ingress and domain
4. **Add CI/CD**: Build and deploy apps automatically
5. **Implement Secrets**: Use Google Secret Manager

---

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)

---

**Documentation Version**: 1.0
**Last Updated**: December 2024
**Tested On**: Windows PowerShell, GCP, GitHub Actions