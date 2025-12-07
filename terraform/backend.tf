terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"  # Replace with your bucket name
    prefix = "terraform/gke/state"
  }
}