project_id   = "epitech-vpc-demo-69"
region       = "europe-west9"
network_name = "network-prod"
ip_range     = "10.0.0.0/24"
user_email   = "arnassalomlucas@gmail.com"

# Paramètres du cluster Kubernetes
cluster_name       = "gke-prod-cluster"
gke_num_nodes      = 2
machine_type       = "e2-medium" # Type de machine standard pour la production
kubernetes_version = "1.27"
node_zones         = ["europe-west9-a", "europe-west9-b", "europe-west9-c"] # Multi-zone pour la haute disponibilité