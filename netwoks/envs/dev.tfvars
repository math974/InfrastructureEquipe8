project_id   = "caramel-abacus-472612-h3"
region       = "europe-west9"
network_name = "network-dev"
<<<<<<< HEAD:netwoks/envs/dev.tfvars
ip_range     = "10.0.0.0/20"
=======
ip_range     = "10.0.0.0/24"
user_email   = "arnassalomlucas@gmail.com"

# Paramètres du cluster Kubernetes
cluster_name      = "gke-dev-cluster"
gke_num_nodes     = 1
machine_type      = "e2-small"  # Type de machine économique pour le développement
kubernetes_version = "1.27"
node_zones        = ["europe-west9-a"]  # Une seule zone pour le dev
>>>>>>> github-action:envs/dev.tfvars
