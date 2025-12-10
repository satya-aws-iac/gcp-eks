# GKE Autopilot - Serverless, Pay-per-Pod model
# This is cheaper for small workloads as you only pay for what you use
# No management fee, no node pool management needed

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

# GKE Autopilot Cluster - Fully Managed
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

  # Maintenance windows
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}