terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  # Remote state backend (GCS).
  # Bucket and prefix are provided by the deploy/destroy scripts using -backend-config
  # for each environment/workspace (see configs/dev.config and configs/prd.config).
  backend "gcs" {}
}
