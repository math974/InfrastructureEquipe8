/**
 * CONFIGURATION D'UN CLUSTER KUBERNETES GKE
 * 
 * Ce fichier définit un cluster GKE (Google Kubernetes Engine) complet
 * qui s'intègre avec l'infrastructure VPC existante.
 * 
 * Cette configuration respecte les exigences des Cours 5 et 7 :
 * - Cours 5 : Node Pools, Control Plane géré, IAM/RBAC
 * - Cours 7 : Load Balancing, HPA, Cluster Autoscaler
 * 
 * Caractéristiques :
 * - Mode STANDARD (pas Autopilot) pour un contrôle total
 * - Node pools personnalisables avec Cluster Autoscaler
 * - Support IPv4/IPv6 dual-stack
 * - Petites instances pour optimiser les coûts
 * - Prêt pour HPA et scaling horizontal complet
 */

# Définition des variables nécessaires pour le cluster Kubernetes
variable "cluster_name" {
  type        = string
  description = "Nom du cluster Kubernetes"
  default     = "gke-cluster"
}

variable "gke_num_nodes" {
  type        = number
  description = "Nombre de nœuds par zone dans le cluster"
  default     = 1
}

variable "machine_type" {
  type        = string
  description = "Type de machine pour les nœuds"
  default     = "e2-medium"
}

variable "kubernetes_version" {
  type        = string
  description = "Version de Kubernetes à utiliser"
  default     = "1.27"  # Version stable au moment de la création
}

variable "node_zones" {
  type        = list(string)
  description = "Liste des zones pour les nœuds du cluster"
  default     = ["europe-west9-a", "europe-west9-b", "europe-west9-c"]
}

# Définition du cluster principal
resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.region  # Utilise la région définie globalement
  project            = var.project_id
  
  # Utilise le réseau VPC existant
  network            = google_compute_network.main.name
  subnetwork         = google_compute_subnetwork.main.name
  
  # Configuration réseau avec plages secondaires (Cours 5, Section 3.5)
  # Utilise les plages IPv4/IPv6 définies dans vpc_subnet.tf
  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = "services-range"
    cluster_secondary_range_name  = "pod-ranges"
  }
  
  # Configuration de la version Kubernetes
  min_master_version = var.kubernetes_version
  
  # Suppression du node pool par défaut (nous créerons le nôtre)
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Configuration du plan de contrôle (Cours 5, Section 3.1)
  # Le control plane est géré par GKE (API server, etcd, scheduler, controllers)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # Contrôle d'accès au plan de contrôle (API server)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "public-access"
    }
  }
  
  # Configuration de maintenance (Cours 5, Section 3.4)
  # Fenêtres de maintenance pour les upgrades automatiques
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

# Définition du node pool pour le cluster (Cours 5, Section 3.2)
# Les node pools permettent de grouper des nœuds avec la même configuration
# et d'appliquer des règles d'autoscaling indépendantes
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  
  # Distribution des nœuds par zone pour la haute disponibilité
  node_locations = var.node_zones
  
  # CLUSTER AUTOSCALER (Cours 7, Section 4.2) - OBLIGATOIRE
  # Scale automatiquement les nœuds en fonction de la demande
  # ⚠️ Important : Le billing GCP est basé sur les nœuds (VMs), pas les pods
  # Cette configuration permet d'optimiser les coûts en ajustant le nombre de nœuds
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  
  # Configuration de gestion des nœuds (Cours 5, Section 3.4)
  management {
    auto_repair  = true  # Répare automatiquement les nœuds défaillants
    auto_upgrade = true  # Met à jour automatiquement les nœuds
  }
  
  # Configuration des nœuds
  node_config {
    # Cours 7, Section 4.2 : "Choose smaller node instances (CPU & RAM)"
    # Petites instances pour optimiser les coûts (e2-small ou e2-medium)
    # Stratégie : 1-2 pods par nœud, puis scale les nœuds
    machine_type = var.machine_type
    
    # Labels Kubernetes (Cours 5, Section 2.2)
    # Utilisés par les selectors pour router les pods
    labels = {
      env  = var.network_name  # dev ou prod selon l'environnement
      pool = "application-pool"
    }
    
    # Métadonnées de sécurité
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Scopes OAuth pour les nœuds (Cours 5, Section 3.3 - IAM)
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  # Configuration de mise à l'échelle progressive (Cours 5, Section 3.2)
  # Upgrade incrémental des nœuds sans downtime
  upgrade_settings {
    max_surge       = 1  # Ajoute 1 nœud pendant l'upgrade
    max_unavailable = 0  # Aucun nœud ne peut être indisponible
  }
}

# Outputs pour accéder au cluster
output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Nom du cluster GKE"
}

output "kubernetes_cluster_host" {
  value       = "https://${google_container_cluster.primary.endpoint}"
  description = "Point d'entrée de l'API Kubernetes"
}

output "kubernetes_location" {
  value       = google_container_cluster.primary.location
  description = "Région/zone du cluster GKE"
}

output "get_credentials_command" {
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
  description = "Commande pour configurer kubectl avec ce cluster"
}
