# Copy this file to terraform.tfvars and update with your values
# DO NOT commit terraform.tfvars to git - add it to .gitignore

project_id     = "satya-k8-poc"
region         = "us-central1"
cluster_name   = "my-gke-cluster"
environment    = "dev"
machine_type   = "e2-medium" # 2 vCPU, 4 GB RAM
node_count     = 2
min_node_count = 2
max_node_count = 2
preemptible    = true # Use preemptible for cost savings