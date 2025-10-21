# Configuration pour l'environnement de développement

# Configuration de base
project_id  = "caramel-abacus-472612-h3"
region      = "europe-west9"
environment = "dev"
user_email  = "mathias.ballot974@gmail.com"

# Configuration réseau
network_config = {
  network_name = "network-dev"
  ip_range     = "10.0.0.0/24"
}

# Configuration Kubernetes
kubernetes_config = {
  cluster_name       = "gke-dev-cluster"
  gke_num_nodes      = 1
  machine_type       = "e2-small"
  kubernetes_version = "1.27"
}

# Configuration IAM
team_member_emails = [
  "arnassalomlucas@gmail.com",
  "mathias.ballot974@gmail.com"
]
team_role                 = "roles/editor"
instructor_email          = "jeremie@jjaouen.com"
enable_instructor_binding = false
auto_invite_missing_users = true
billing_account_id        = "0100E9-D328A7-35D6BE"
