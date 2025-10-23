# Variables globales pour l'infrastructure complète

variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west9"
}

variable "environment" {
  description = "Environnement (dev ou prd)"
  type        = string
  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "L'environnement doit être 'dev' ou 'prd'."
  }
}

variable "user_email" {
  description = "Email de l'utilisateur pour les permissions IAM"
  type        = string
}

# Variables IAM
variable "team_member_emails" {
  description = "List of team member emails"
  type        = list(string)
  default     = []
}

variable "team_role" {
  description = "IAM role granted to team members"
  type        = string
  default     = "roles/editor"
}

variable "instructor_email" {
  description = "Instructor email"
  type        = string
  default     = ""
}

variable "instructor_role" {
  description = "Least-privilege role for instructor"
  type        = string
  default     = "roles/viewer"
}

variable "enable_instructor_binding" {
  description = "Whether to create instructor IAM binding"
  type        = bool
  default     = false
}

variable "auto_invite_missing_users" {
  description = "If true, ensure IAM membership for all emails"
  type        = bool
  default     = true
}

variable "billing_account_id" {
  description = "Billing account ID for IAM bindings"
  type        = string
  default     = "0100E9-D328A7-35D6BE"
}

# Variables spécifiques à l'environnement
variable "kubernetes_config" {
  description = "Configuration spécifique pour Kubernetes"
  type = object({
    cluster_name       = optional(string, "gke-cluster")
    gke_num_nodes      = optional(number, 1)
    machine_type       = optional(string, "e2-medium")
    kubernetes_version = optional(string, "1.27")
    node_zones         = optional(list(string), [])
  })
  default = {}
}

variable "database_config" {
  description = "Configuration spécifique pour la base de données Cloud SQL"
  type = object({
    instance_name         = optional(string, "tasks-mysql")
    db_name               = optional(string, "tasksdb")
    db_user               = optional(string, "tasks_app")
    db_tier               = optional(string, "db-f1-micro")
    db_version            = optional(string, "MYSQL_8_0")
    private_ip_prefix_len = optional(number, 16)
  })
  default = {}
}

variable "network_config" {
  description = "Configuration spécifique pour le réseau"
  type = object({
    network_name = string
    ip_range     = string
  })
}

variable "bootstrap" {
  description = "Bootstrap mode flag"
  type        = bool
  default     = false
}
