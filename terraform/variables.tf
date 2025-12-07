variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (for single-zone cluster to save costs)"
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

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-micro"  # Free tier eligible, 2 vCPU, 1GB RAM
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 1  # Reduced to 1 node for free tier
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3  # Reduced max to 3
}

variable "preemptible" {
  description = "Use preemptible nodes (cheaper but can be terminated)"
  type        = bool
  default     = true  # Changed to true for cost savings
}