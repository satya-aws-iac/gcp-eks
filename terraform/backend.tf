terraform {
  backend "gcs" {
    bucket = "satya-k8-poc-terraform-state"
    prefix = "terraform/gke/state"
  }
}


