variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "environment" {
  description = "Environnement (dev ou prd)"
  type        = string
  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "L'environnement doit être 'dev' ou 'prd'."
  }
}

variable "pool_id" {
  description = "ID du Workload Identity Pool"
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "ID du Workload Identity Provider"
  type        = string
  default     = "github"
}

variable "service_account_id" {
  description = "ID (name) du service account Terraform"
  type        = string
  default     = "github-terraform"
}

variable "service_account_display_name" {
  description = "Nom d'affichage du service account"
  type        = string
  default     = "GitHub Terraform"
}

variable "github_owner" {
  description = "Organisation ou utilisateur GitHub"
  type        = string
}

variable "github_repo" {
  description = "Nom du dépôt GitHub"
  type        = string
}

variable "allowed_branches" {
  description = "Branches autorisées pour cet environnement"
  type        = list(string)
  default     = []
}

variable "roles" {
  description = "Liste des rôles à attribuer au service account"
  type        = list(string)
  default = [
    "roles/storage.admin",
    "roles/storage.objectViewer",
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.securityAdmin",
    "roles/secretmanager.admin",
    "roles/viewer",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/artifactregistry.admin",
    "roles/artifactregistry.writer"
  ]
}