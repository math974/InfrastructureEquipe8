variable "project_id" {
  description = "ID du projet GCP"
  type        = string
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

variable "branch_excluded" {
  description = "Nom de la branche à exclure (ex: master)"
  type        = string
  default     = "master"
}

variable "roles" {
  description = "Liste des rôles à attribuer au service account"
  type        = list(string)
  default = [
    "roles/storage.admin",
    "roles/storage.objectViewer",
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/viewer",
  ]
}

