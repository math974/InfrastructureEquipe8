# Configuration principale Terraform
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

# Variables globales déclarées dans variables.tf

# Module Network
module "network" {
  source = "./modules/network"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_config.network_name
  ip_range     = var.network_config.ip_range
}

# Module IAM
module "iam" {
  source = "./modules/iam"

  project_id                = var.project_id
  team_member_emails        = var.team_member_emails
  team_role                 = var.team_role
  instructor_email          = var.instructor_email
  instructor_role           = var.instructor_role
  enable_instructor_binding = var.enable_instructor_binding
  auto_invite_missing_users = var.auto_invite_missing_users
  billing_account_id        = var.billing_account_id
  user_email                = var.user_email
}

# Module Kubernetes (dépend du réseau et des permissions IAM)
module "kubernetes" {
  source = "./modules/kubernetes"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  network_name = module.network.network_name
  subnet_name  = module.network.subnet_name

  # Configuration Kubernetes
  cluster_name       = var.kubernetes_config.cluster_name
  gke_num_nodes      = var.kubernetes_config.gke_num_nodes
  machine_type       = var.kubernetes_config.machine_type
  kubernetes_version = var.kubernetes_config.kubernetes_version

  depends_on = [module.network, module.iam]
}
