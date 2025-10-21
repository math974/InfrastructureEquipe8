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

variable "network_name" {
  description = "Nom du réseau VPC"
  type        = string
}

variable "subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
  default     = "gke-cluster"
}

variable "gke_num_nodes" {
  description = "Nombre de nœuds par zone dans le cluster"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Type de machine pour les nœuds"
  type        = string
  default     = "e2-medium"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes à utiliser"
  type        = string
  default     = "1.27"
}

variable "node_zones" {
  description = "Liste des zones pour les nœuds du cluster"
  type        = list(string)
  default     = ["europe-west9-a", "europe-west9-b", "europe-west9-c"]
}

variable "user_email" {
  description = "Email de l'utilisateur pour les permissions IAM"
  type        = string
}
