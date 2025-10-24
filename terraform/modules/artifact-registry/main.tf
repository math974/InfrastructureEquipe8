# Module Artifact Registry - Gestion des registries Docker et permissions IAM

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Artifact Registry pour les images Docker
resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.repository_name}-${var.environment}"
  description   = "Docker repository for ${var.environment} environment"
  format        = "DOCKER"

  labels = {
    environment = var.environment
    purpose     = "docker-images"
  }

  # Configuration de la rétention des images
  cleanup_policies {
    id     = "delete-prerelease"
    action = "DELETE"
    condition {
      tag_state = "TAGGED"
      tag_prefixes = [
        "dev-",
        "test-",
        "staging-"
      ]
      older_than = "604800s" # 7 jours
    }
  }

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    condition {
      tag_state = "TAGGED"
      tag_prefixes = [
        "v",
        "prod-"
      ]
    }
  }
}

# Les permissions IAM sont gérées par les modules iam/ et bootstrap-wif/
# Ce module se contente de créer le registry Artifact Registry
