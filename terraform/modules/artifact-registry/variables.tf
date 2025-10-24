# Variables pour le module Artifact Registry

variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP pour le registry"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "repository_name" {
  description = "Nom du repository Artifact Registry"
  type        = string
  default     = "tasks-app"
}

# Les variables IAM sont gérées par les modules iam/ et bootstrap-wif/

variable "retention_days" {
  description = "Nombre de jours de rétention pour les images de développement"
  type        = number
  default     = 7
}

variable "cleanup_policies" {
  description = "Politiques de nettoyage personnalisées"
  type = list(object({
    id     = string
    action = string
    condition = object({
      tag_state    = optional(string)
      tag_prefixes = optional(list(string))
      older_than   = optional(string)
    })
  }))
  default = []
}
