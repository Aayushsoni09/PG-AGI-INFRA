terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "pgagi-tfstate-gcp"
    prefix = "gcp/dev"
  }
}

provider "google" {
  project = "pgagi-task"
  region  = "asia-south1"
}
