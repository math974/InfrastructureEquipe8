terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  backend "gcs" {}
}

# Variables nécessaires pour le module Kubernetes
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

# Référence au réseau VPC existant
data "google_compute_network" "main" {
  name    = var.network_name
  project = var.project_id
}

data "google_compute_subnetwork" "main" {
  name    = var.subnet_name
  region  = var.region
  project = var.project_id
}

# Cluster GKE
resource "google_container_cluster" "primary" {
  name               = "${var.cluster_name}-${var.environment}"
  location           = var.region
  project            = var.project_id
  
  # Utilise le réseau VPC existant
  network            = data.google_compute_network.main.name
  subnetwork         = data.google_compute_subnetwork.main.name
  
  # Configuration réseau avec plages secondaires
  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = "services-range"
    cluster_secondary_range_name  = "pod-ranges"
  }
  
  # Configuration de la version Kubernetes
  min_master_version = var.kubernetes_version
  
  # Suppression du node pool par défaut
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Configuration du plan de contrôle
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # Contrôle d'accès au plan de contrôle
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "public-access"
    }
  }
  
  # Configuration de maintenance
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }
  
  # Protection contre la suppression accidentelle
  deletion_protection = false
}

# Node pool pour le cluster
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  
  # Distribution des nœuds par zone
  node_locations = var.node_zones
  
  # Cluster Autoscaler
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  
  # Configuration de gestion des nœuds
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # Configuration des nœuds
  node_config {
    machine_type = var.machine_type
    
    # Labels Kubernetes
    labels = {
      env  = var.environment
      pool = "application-pool"
    }
    
    # Métadonnées de sécurité
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Scopes OAuth pour les nœuds
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  # Configuration de mise à l'échelle progressive
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Permissions IAM pour Kubernetes
resource "google_project_iam_member" "container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "user:${var.user_email}"
}

resource "google_project_iam_member" "compute_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "user:${var.user_email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "user:${var.user_email}"
}
