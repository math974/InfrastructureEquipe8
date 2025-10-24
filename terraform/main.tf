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
  region                    = var.region
  environment               = var.environment
}

# Module Database (dépend du réseau)
module "database" {
  source = "./modules/database"

  project_id        = var.project_id
  region            = var.region
  network_self_link = module.network.network_self_link
  network_name      = module.network.network_name

  instance_name         = var.database_config.instance_name
  db_name               = var.database_config.db_name
  db_user               = var.database_config.db_user
  db_tier               = var.database_config.db_tier
  db_version            = var.database_config.db_version
  private_ip_prefix_len = var.database_config.private_ip_prefix_len

  depends_on = [module.network]
}

# Module Artifact Registry
module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  repository_name = var.artifact_registry_config.repository_name

  # Configuration de rétention
  retention_days = var.artifact_registry_config.retention_days
  cleanup_policies = var.artifact_registry_config.cleanup_policies
}

# Module Kubernetes (dépend du réseau, IAM, base de données et Artifact Registry)
module "kubernetes" {
  source = "./modules/kubernetes"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  network_name = module.network.network_name
  subnet_name  = module.network.subnet_name

  # Configuration Kubernetes
  cluster_name                = var.kubernetes_config.cluster_name
  gke_num_nodes               = var.kubernetes_config.gke_num_nodes
  machine_type                = var.kubernetes_config.machine_type
  kubernetes_version          = var.kubernetes_config.kubernetes_version
  node_zones                  = var.kubernetes_config.node_zones
  nodes_service_account_email = module.iam.gke_nodes_service_account_email

  depends_on = [module.network, module.iam, module.database, module.artifact_registry]
}
