terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Variables: définies dans variables.tf du module

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
  name     = "${var.cluster_name}-${var.environment}"
  location = var.region
  project  = var.project_id

  # Utilise le réseau VPC existant
  network    = data.google_compute_network.main.name
  subnetwork = data.google_compute_subnetwork.main.name

  # Configuration réseau avec plages secondaires
  ip_allocation_policy {
    stack_type                    = "IPV4"
    services_secondary_range_name = "services-range-2"
    cluster_secondary_range_name  = "pod-ranges-2"
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

  # Maintenance policy retirée pour satisfaire les contraintes d'availability GKE

  # Protection contre la suppression accidentelle
  deletion_protection = false

  # Configuration des nœuds
  node_config {
    machine_type    = var.machine_type
    service_account = var.nodes_service_account_email

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
}

# Node pool pour le cluster
resource "google_container_node_pool" "primary_nodes" {
  name     = "${google_container_cluster.primary.name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Distribution des nœuds par zone
  node_locations = var.node_zones

  # Cluster Autoscaler
  autoscaling {
    min_node_count = 1
    max_node_count = 3
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

  # Limiter le nombre de pods par nœud
  max_pods_per_node = var.max_pods_per_node

  # Configuration de mise à l'échelle progressive
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

