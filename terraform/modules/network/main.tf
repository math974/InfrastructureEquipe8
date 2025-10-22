# Module Network - Configuration VPC et sous-réseaux

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# VPC
resource "google_compute_network" "main" {
  name                     = var.network_name
  project                  = var.project_id
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

# Sous-réseau principal
resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.ip_range
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.main.id

  # Support IPv4/IPv6 dual-stack
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"

  # Plages secondaires pour les pods et services Kubernetes
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }

  # Ranges additionnelles pour capacité accrue sans modifier les existantes
  secondary_ip_range {
    range_name    = "services-range-2"
    ip_cidr_range = "10.10.0.0/22"
  }

  secondary_ip_range {
    range_name    = "pod-ranges-2"
    ip_cidr_range = "10.20.0.0/20"
  }
}
