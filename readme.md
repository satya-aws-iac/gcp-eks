# GKE Cluster with GitHub Actions CI/CD

[![Terraform](https://img.shields.io/badge/Terraform-v1.6-623CE4?logo=terraform)](https://www.terraform.io/)
[![GCP](https://img.shields.io/badge/GCP-Standard_GKE-4285F4?logo=google-cloud)](https://cloud.google.com/kubernetes-engine)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions)](https://github.com/features/actions)
[![OIDC](https://img.shields.io/badge/Auth-OIDC-10B981?logo=auth0)](https://openid.net/connect/)

> Production-ready Google Kubernetes Engine cluster with automated CI/CD, OIDC authentication, and Infrastructure as Code using Terraform.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/satya-aws-iac/gcp-eks.git
cd gcp-eks

# Access your cluster
gcloud container clusters get-credentials my-gke-cluster \
    --zone us-central1-a \
    --project satya-k8-poc

# Verify
kubectl get nodes
```

## 📋 Overview

This repository contains the complete infrastructure setup for a **Standard GKE cluster** running on Google Cloud Platform, managed through **GitHub Actions** with **Terraform**.

### Current Setup

| Component | Details |
|-----------|---------|
| **Cluster Name** | `my-gke-cluster` |
| **Location** | `us-central1-a` (single zone) |
| **Nodes** | 2 × e2-small (2 vCPU, 2GB RAM) |
| **Node Type** | Preemptible (80% cost savings) |
| **Disk** | 30GB standard disk per node |
| **Autoscaling** | 1-3 nodes |
| **Monthly Cost** | ~$96 |

### Key Features

- ✅ **Secure**: OIDC Workload Identity (no service account keys)
- ✅ **Automated**: GitOps workflow (stage → main)
- ✅ **Safe**: Terraform plan review before apply
- ✅ **Monitored**: Health checks every 6 hours
- ✅ **Cost-Optimized**: Preemptible nodes, single zone

## 🏗️ Architecture

```
┌─────────────────┐
│  GitHub Repo    │
│  (stage/main)   │
└────────┬────────┘
         │
         │ Push to stage
         ▼
┌─────────────────┐
│ Terraform Plan  │ ──► Review in GitHub Issues
└────────┬────────┘
         │
         │ Merge to main
         ▼
┌─────────────────┐
│ Terraform Apply │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│   GCP: satya-k8-poc         │
│   ┌─────────────────────┐   │
│   │  GKE Cluster        │   │
│   │  2 × e2-small nodes │   │
│   └─────────────────────┘   │
└─────────────────────────────┘
```

## 📁 Repository Structure

```
gcp-eks/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml       # Plan on stage push
│       ├── terraform-apply.yml      # Apply on main push
│       ├── stage-validation.yml     # Full validation
│       ├── cluster-health.yml       # Health monitoring
│       ├── terraform-destroy.yml    # Cluster deletion
│       ├── terraform-unlock.yml     # State unlock
│       └── promote-to-main.yml      # Stage promotion
├── terraform/
│   ├── main.tf                      # GKE cluster definition
│   ├── variables.tf                 # Input variables
│   ├── outputs.tf                   # Output values
│   └── backend.tf                   # GCS backend config
├── documentation.html               # Complete guide (HTML)
└── README.md                        # This file
```

## 🔄 Workflow

### Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/my-change

# 2. Make changes to Terraform files
vim terraform/main.tf

# 3. Test in stage
git checkout stage
git merge feature/my-change
git push origin stage        # ← Triggers plan

# 4. Review plan in GitHub Actions/Issues

# 5. Deploy to production
git checkout main
git merge stage
git push origin main         # ← Triggers apply
```

### Branch Strategy

```
feature/xyz → stage → main
    ↓          ↓      ↓
  (dev)     (plan)  (apply)
```

## 📖 Documentation

- **📄 [Complete HTML Guide](./documentation.html)** - Open in browser for full documentation
- **🔗 [GitHub Actions](https://github.com/satya-aws-iac/gcp-eks/actions)** - View workflow runs
- **🔗 [GCP Console](https://console.cloud.google.com/kubernetes/list?project=satya-k8-poc)** - View cluster

## 🔐 Security

### Authentication
- **OIDC Workload Identity Federation** (no service account keys!)
- Short-lived tokens (1 hour)
- Repository-specific access

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | OIDC provider resource name |
| `GCP_SERVICE_ACCOUNT` | github-actions-gke@satya-k8-poc.iam.gserviceaccount.com |
| `GCP_PROJECT_ID` | satya-k8-poc |
| `GCP_REGION` | us-central1 |
| `GKE_CLUSTER_NAME` | my-gke-cluster |

## ⚙️ Operations

### Access Cluster

```bash
gcloud container clusters get-credentials my-gke-cluster \
    --zone us-central1-a \
    --project satya-k8-poc

kubectl get nodes
kubectl get pods --all-namespaces
```

### Deploy Application

```bash
# Deploy nginx example
kubectl create deployment nginx --image=nginx:latest
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx
```

### Scale Cluster

```bash
# Scale to 3 nodes
gcloud container clusters resize my-gke-cluster \
    --num-nodes=3 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool

# Scale back to 2
gcloud container clusters resize my-gke-cluster \
    --num-nodes=2 \
    --zone=us-central1-a \
    --node-pool=my-gke-cluster-node-pool
```

### Health Check

```bash
# Manual health check
kubectl cluster-info
kubectl get nodes -o wide
kubectl top nodes

# Or run workflow: Actions → GKE Cluster Health Check
```

### Destroy Cluster

```bash
# Via GitHub Actions (Recommended)
# Go to: Actions → Terraform Destroy → Run workflow → Type "destroy"

# Or manually
cd terraform
terraform destroy -var="project_id=satya-k8-poc"
```

## 💰 Cost Management

### Current Costs (~$96/month)

| Item | Cost |
|------|------|
| GKE Management | $73/month |
| 2× e2-small nodes | $15/month |
| 2× 30GB disks | $6/month |
| Network | $2/month |

### Cost Optimization

1. **Scale down when not in use**
   ```bash
   gcloud container clusters resize my-gke-cluster --num-nodes=1 --zone=us-central1-a
   ```
   Saves: ~$7/month

2. **Delete unused LoadBalancers**
   ```bash
   kubectl delete svc UNUSED_SERVICE
   ```
   Saves: $18/month per LoadBalancer

3. **Destroy cluster when not needed**
   ```bash
   # Actions → Terraform Destroy
   ```
   Saves: $96/month

## 🔧 Troubleshooting

### Common Issues

**Issue: terraform-apply.yml fails on first run**
- **Cause**: Workflow tries to get credentials before cluster exists
- **Solution**: See [documentation.html](./documentation.html#workflows) for fix

**Issue: Out of resources (0/2 nodes available)**
- **Solution**: Scale up nodes or reduce pod resource requests

**Issue: Preemptible node terminated**
- **Normal**: Preemptible nodes can be terminated by GCP
- **Action**: Pods automatically reschedule to other nodes

**Issue: Terraform state locked**
- **Solution**: Run "Terraform Unlock State" workflow

### Debug Commands

```bash
# Check cluster status
gcloud container clusters describe my-gke-cluster --zone=us-central1-a

# Check node issues
kubectl describe node NODE_NAME

# Check pod logs
kubectl logs POD_NAME

# View recent events
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

## 📊 Monitoring

### Automatic Health Checks
- Runs every 6 hours via GitHub Actions
- Checks: nodes, pods, services, events
- Manual trigger: Actions → GKE Cluster Health Check

### GCP Monitoring
```bash
# Enable monitoring
gcloud container clusters update my-gke-cluster \
    --enable-cloud-monitoring \
    --zone=us-central1-a
```

## 🚦 GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| terraform-plan.yml | Push to `stage` | Validate and plan changes |
| terraform-apply.yml | Push to `main` | Apply infrastructure |
| stage-validation.yml | Push to `stage` | Complete validation |
| cluster-health.yml | Every 6 hours / Manual | Health monitoring |
| terraform-destroy.yml | Manual | Destroy cluster |
| terraform-unlock.yml | Manual | Unlock state |
| promote-to-main.yml | Manual | Promote stage to main |

## 🛠️ Development

### Prerequisites
- Google Cloud SDK (`gcloud`)
- kubectl
- Terraform (optional, for local testing)
- Git

### Local Testing

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan changes locally
terraform plan \
    -var="project_id=satya-k8-poc" \
    -var="region=us-central1" \
    -var="zone=us-central1-a" \
    -var="cluster_name=my-gke-cluster"

# Apply locally (be careful!)
terraform apply
```

## 📝 Best Practices

### Resource Limits
Always set resource requests and limits:
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Use Namespaces
```bash
kubectl create namespace production
kubectl create deployment app -n production --image=my-app
```

### Use Secrets
```bash
kubectl create secret generic my-secret --from-literal=password=xyz
```

### Regular Backups
```bash
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

## 🔗 Useful Links

- **GCP Console**: https://console.cloud.google.com
- **GKE Clusters**: https://console.cloud.google.com/kubernetes/list?project=satya-k8-poc
- **GitHub Actions**: https://github.com/satya-aws-iac/gcp-eks/actions
- **Terraform State**: https://console.cloud.google.com/storage/browser/satya-k8-poc-terraform-state
- **GKE Documentation**: https://cloud.google.com/kubernetes-engine/docs
- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test in `stage` branch
4. Create a PR to `main`
5. Wait for plan approval
6. Merge to deploy

## 📄 License

This project is maintained by the platform team for internal use.

## 📞 Support

- **Issues**: Check GitHub Actions logs
- **Documentation**: See [documentation.html](./documentation.html)
- **GCP Support**: https://console.cloud.google.com/support

---

## 🎯 Quick Commands Cheat Sheet

```bash
# Access cluster
gcloud container clusters get-credentials my-gke-cluster --zone us-central1-a --project satya-k8-poc

# View resources
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Deploy app
kubectl create deployment app --image=nginx
kubectl expose deployment app --port=80 --type=LoadBalancer

# Scale nodes
gcloud container clusters resize my-gke-cluster --num-nodes=3 --zone=us-central1-a

# Check costs
gcloud billing accounts list
gcloud billing projects describe satya-k8-poc

# Destroy
# Actions → Terraform Destroy → Type "destroy"
```

---

**Project**: satya-k8-poc  
**Repository**: satya-aws-iac/gcp-eks  
**Maintained by**: Platform Team  
**Last Updated**: December 2024

⭐ **Star this repo** if you find it helpful!