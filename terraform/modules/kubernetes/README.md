# Module Kubernetes - GKE

Ce module Terraform déploie un cluster Google Kubernetes Engine (GKE) complet avec une application de démonstration.

## Architecture

- **Cluster GKE** : Cluster Kubernetes géré avec autoscaling
- **Node Pools** : Pools de nœuds avec auto-repair et auto-upgrade
- **Application Simple** : Application Flask containerisée pour démonstration
- **Load Balancer** : Ingress avec Load Balancer GCP

## Structure

```
kubernetes/
├── main.tf                    # Configuration principale du cluster GKE
├── variables.tf               # Variables du module
├── outputs.tf                 # Outputs du module
├── envs/                      # Configuration par environnement
│   ├── dev.tfvars
│   └── prd.tfvars
├── simple-app/                # Application de démonstration
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   └── k8s-deployment.yaml
└── deploy-app.sh             # Script de déploiement de l'application
```

## Déploiement

### 1. Déploiement de l'infrastructure

```bash
# Déploiement complet (networks + iam + kubernetes)
./deploy_all.sh

# Ou déploiement manuel du module Kubernetes
cd kubernetes
terraform init -backend-config=../configs/kubernetes-dev.config
terraform apply -var-file=envs/dev.tfvars
```

### 2. Déploiement de l'application

```bash
# Déploiement automatique avec le script
./kubernetes/deploy-app.sh dev YOUR_PROJECT_ID

# Ou déploiement manuel
cd kubernetes/simple-app
docker build -t gcr.io/YOUR_PROJECT_ID/simple-app:latest .
docker push gcr.io/YOUR_PROJECT_ID/simple-app:latest

# Configuration kubectl
gcloud container clusters get-credentials gke-cluster-dev --region europe-west9 --project YOUR_PROJECT_ID

# Déploiement sur Kubernetes
kubectl apply -f k8s-deployment.yaml
```

## Configuration

### Variables requises

- `project_id` : ID du projet GCP
- `region` : Région GCP (défaut: europe-west9)
- `environment` : Environnement (dev/prd)
- `network_name` : Nom du réseau VPC
- `subnet_name` : Nom du sous-réseau
- `user_email` : Email pour les permissions IAM

### Variables optionnelles

- `cluster_name` : Nom du cluster (défaut: gke-cluster)
- `gke_num_nodes` : Nombre de nœuds par zone (défaut: 1)
- `machine_type` : Type de machine (défaut: e2-medium)
- `kubernetes_version` : Version Kubernetes (défaut: 1.27)

## Application de démonstration

L'application simple inclut :

- **Endpoint principal** (`/`) : Informations sur l'application
- **Health check** (`/health`) : Vérification de santé
- **Info détaillée** (`/info`) : Informations sur l'environnement Kubernetes
- **Echo** (`/echo`) : Test des requêtes POST

### Test de l'application

```bash
# Port-forward pour accéder localement
kubectl port-forward service/simple-app-service 8080:80

# Test des endpoints
curl http://localhost:8080
curl http://localhost:8080/health
curl http://localhost:8080/info
curl -X POST http://localhost:8080/echo -H "Content-Type: application/json" -d '{"test": "data"}'
```

## GitHub Actions

Le workflow GitHub Actions automatise :

1. **Validation** : Format et validation Terraform
2. **Plan** : Plan d'exécution pour les PR
3. **Apply** : Déploiement automatique sur push
4. **Build & Deploy** : Construction et déploiement de l'application

### Secrets requis

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`

## Monitoring et Logs

```bash
# Vérifier les pods
kubectl get pods -l app=simple-app

# Voir les logs
kubectl logs -l app=simple-app

# Vérifier les services
kubectl get services

# Vérifier l'ingress
kubectl get ingress
```

## Scaling

Le cluster utilise l'autoscaling automatique :

- **Min nodes** : 1
- **Max nodes** : 5
- **HPA** : Prêt pour Horizontal Pod Autoscaler

## Sécurité

- Cluster privé avec endpoint privé
- Workload Identity pour l'authentification
- RBAC configuré
- Network policies supportées
