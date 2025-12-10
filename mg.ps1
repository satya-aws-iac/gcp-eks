# Migrate from GKE Autopilot to Standard GKE with 2 nodes
# This script updates all necessary files

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Migrate to Standard GKE with 2 Nodes                " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "ERROR: Not in a git repository" -ForegroundColor Red
    Write-Host "Please run this script from your repository root" -ForegroundColor Yellow
    exit 1
}

Write-Host "WARNING: This will update your Terraform and workflow files" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Type 'YES' to continue"

if ($confirm -ne "YES") {
    Write-Host "Migration cancelled" -ForegroundColor Yellow
    exit 0
}

# Create backup
Write-Host "`nCreating backup..." -ForegroundColor Yellow
$backupDir = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
Copy-Item -Path "terraform" -Destination "$backupDir/terraform" -Recurse -Force
Copy-Item -Path ".github" -Destination "$backupDir/.github" -Recurse -Force
Write-Host "Backup created in: $backupDir" -ForegroundColor Green

# Update main.tf
Write-Host "`nUpdating terraform/main.tf..." -ForegroundColor Yellow
$mainTf = @'
# Standard GKE Cluster with 2 Small Nodes
# Cost-optimized configuration for learning/development

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
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
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

# Standard GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
  
  deletion_protection = false
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  release_channel {
    channel = "REGULAR"
  }
}

# Node Pool with 2 nodes
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 30
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = var.environment
    }

    tags = ["gke-node", "${var.cluster_name}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service Account for nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-gke-nodes"
  display_name = "Service Account for GKE nodes"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_resource_metadata_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
'@

$mainTf | Out-File -FilePath "terraform/main.tf" -Encoding UTF8
Write-Host "main.tf updated" -ForegroundColor Green

# Update variables.tf
Write-Host "`nUpdating terraform/variables.tf..." -ForegroundColor Yellow
$variablesTf = @'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1-a"
}

variable "zone" {
  description = "GCP zone (single zone for cost savings)"
  type        = string
  default     = "us-central1-a-a"
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
'@

$variablesTf | Out-File -FilePath "terraform/variables.tf" -Encoding UTF8
Write-Host "variables.tf updated" -ForegroundColor Green

# Update outputs.tf
Write-Host "`nUpdating terraform/outputs.tf..." -ForegroundColor Yellow
$outputsTf = @'
output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "vpc_name" {
  description = "VPC name"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.subnet.name
}

output "node_pool_name" {
  description = "Node pool name"
  value       = google_container_node_pool.primary_nodes.name
}

output "node_count" {
  description = "Number of nodes"
  value       = google_container_node_pool.primary_nodes.node_count
}

output "machine_type" {
  description = "Node machine type"
  value       = "e2-small"
}
'@

$outputsTf | Out-File -FilePath "terraform/outputs.tf" -Encoding UTF8
Write-Host "outputs.tf updated" -ForegroundColor Green

# Instructions for workflows
Write-Host "`n========================================================" -ForegroundColor Yellow
Write-Host "   MANUAL STEPS REQUIRED:" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Add GitHub Secret:" -ForegroundColor White
Write-Host "   - Go to: Settings -> Secrets and variables -> Actions" -ForegroundColor Gray
Write-Host "   - Click: New repository secret" -ForegroundColor Gray
Write-Host "   - Name: GCP_ZONE" -ForegroundColor Gray
Write-Host "   - Value: us-central1-a-a" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Update Workflow Files:" -ForegroundColor White
Write-Host "   In each workflow file, add this to terraform plan/apply:" -ForegroundColor Gray
Write-Host '   -var="zone=DOLLAR{{ secrets.GCP_ZONE }}"' -ForegroundColor Yellow
Write-Host "   (Replace DOLLAR with actual dollar sign)" -ForegroundColor Gray
Write-Host ""
Write-Host "   Files to update:" -ForegroundColor Gray
Write-Host "   - .github/workflows/terraform-plan.yml" -ForegroundColor Gray
Write-Host "   - .github/workflows/terraform-apply.yml" -ForegroundColor Gray
Write-Host "   - .github/workflows/stage-validation.yml" -ForegroundColor Gray
Write-Host ""
Write-Host "   Also change all occurrences:" -ForegroundColor Gray
Write-Host "   --region DOLLAR{{ secrets.GCP_REGION }}" -ForegroundColor Gray
Write-Host "   TO:" -ForegroundColor Gray
Write-Host "   --zone DOLLAR{{ secrets.GCP_ZONE }}" -ForegroundColor Yellow
Write-Host ""

Write-Host "3. Destroy Autopilot Cluster First:" -ForegroundColor White
Write-Host "   - Go to: Actions -> Terraform Destroy" -ForegroundColor Gray
Write-Host "   - Click: Run workflow" -ForegroundColor Gray
Write-Host "   - Type: destroy" -ForegroundColor Gray
Write-Host "   - Wait for completion (5-10 minutes)" -ForegroundColor Gray
Write-Host ""

# Git status
Write-Host "Git Status:" -ForegroundColor Cyan
git status --short

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "   Terraform files updated!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Complete the manual steps above" -ForegroundColor White
Write-Host "2. Review changes: git diff" -ForegroundColor White
Write-Host "3. Commit changes" -ForegroundColor White
Write-Host "4. Push to stage first: git push origin stage" -ForegroundColor White
Write-Host "5. Review plan, then push to main" -ForegroundColor White
Write-Host ""
Write-Host "Backup location: $backupDir" -ForegroundColor Cyan
Write-Host ""