# Configuration pour l'environnement de production

# Configuration de base
project_id  = "epitech-vpc-demo-69"
region      = "europe-west1"
environment = "prd"
user_email  = "mathias.ballot974@gmail.com"

# Configuration réseau
network_config = {
  network_name = "network-prod"
  ip_range     = "10.0.0.0/24"
}

# Configuration Kubernetes
kubernetes_config = {
  cluster_name       = "gke-prod-cluster"
  gke_num_nodes      = 1
  machine_type       = "e2-medium"
  kubernetes_version = "1.31"
  node_zones         = ["europe-west1-b"]
}

# Configuration Base de Données (Cloud SQL)
database_config = {
  instance_name         = "tasks-mysql-prd"
  db_name               = "tasksdb"
  db_user               = "tasks_app"
  db_tier               = "db-f1-micro"
  db_version            = "MYSQL_8_0"
  private_ip_prefix_len = 16
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
