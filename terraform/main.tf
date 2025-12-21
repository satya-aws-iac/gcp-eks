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

# # Node Pool with 2 nodes
# resource "google_container_node_pool" "primary_nodes" {
#   name       = "${var.cluster_name}-node-pool"
#   location   = var.zone
#   cluster    = google_container_cluster.primary.name
#   node_count = 2

#   node_config {
#     preemptible  = true
#     machine_type = "e2-small"
#     disk_size_gb = 30
#     disk_type    = "pd-standard"

#     service_account = google_service_account.gke_nodes.email
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]

#     labels = {
#       env = var.environment
#     }

#     tags = ["gke-node", "${var.cluster_name}-gke"]

#     metadata = {
#       disable-legacy-endpoints = "true"
#     }

#     workload_metadata_config {
#       mode = "GKE_METADATA"
#     }
#   }

#   autoscaling {
#     min_node_count = 1
#     max_node_count = 3
#   }

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }
# }

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

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count # ✅ Use variable

  node_config {
    preemptible  = var.preemptible  # ✅ Use variable
    machine_type = var.machine_type # ✅ Use variable
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
    min_node_count = var.min_node_count # ✅ Use variable
    max_node_count = var.max_node_count # ✅ Use variable
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}