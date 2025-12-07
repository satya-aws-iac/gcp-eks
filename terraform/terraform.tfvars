# Copy this file to terraform.tfvars and update with your values
# DO NOT commit terraform.tfvars to git - add it to .gitignore

project_id     = "satya-k8-poc"
region         = "us-central1"
zone           = "us-central1-a"  # Single zone for cost savings
cluster_name   = "my-gke-cluster"
environment    = "dev"
machine_type   = "e2-micro"       # Free tier: 2 vCPU, 1GB RAM, 30GB disk
node_count     = 1                # Start with 1 node
min_node_count = 1
max_node_count = 3                # Max 3 nodes
preemptible    = true             # Use preemptible for 80% cost savings