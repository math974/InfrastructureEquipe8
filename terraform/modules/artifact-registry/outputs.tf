# Outputs pour le module Artifact Registry

output "repository_id" {
  description = "ID du repository Artifact Registry"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "repository_name" {
  description = "Nom complet du repository Artifact Registry"
  value       = google_artifact_registry_repository.docker_repo.name
}

output "repository_url" {
  description = "URL du repository Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

# Les outputs IAM sont gérés par les modules iam/ et bootstrap-wif/
