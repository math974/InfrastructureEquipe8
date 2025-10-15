# Infrastructure Kubernetes avec Terraform

Ce projet configure une infrastructure complète pour Kubernetes sur Google Cloud Platform (GCP) en utilisant Terraform.

**Conforme aux exigences des Cours 5 et 7** :
- ✅ Cours 5 : Node Pools personnalisables, Control Plane géré, IAM/RBAC
- ✅ Cours 7 : Load Balancing, HPA, Cluster Autoscaler obligatoire

## Architecture

```
Internet
   │
   ↓
[Load Balancer GCP] ← Cours 7, Section 2
   │
   ↓
[Kubernetes Service] ← Cours 5, Section 2.3
   │
   ↓
[Pods (HPA 1-6)] ← Cours 7, Section 4.1
   │
   ↓
[Nodes (Autoscaler 1-5)] ← Cours 7, Section 4.2 (OBLIGATOIRE)
   │
   ↓
[Cloud SQL (Private)] ← Base de données managée
```

## Composants

- **VPC et Sous-réseaux** : Réseau isolé avec support IPv4/IPv6 dual-stack
- **Plages IP secondaires** : Pour les pods (192.168.1.0/24) et services (192.168.0.0/24)
- **IAM et Permissions** : Rôles nécessaires pour gérer Kubernetes
- **Cluster GKE Standard** : Cluster avec contrôle total (pas Autopilot)
- **Node Pools** : Groupes de nœuds avec Cluster Autoscaler (1-5 nœuds)
- **Petites instances** : e2-small/e2-medium pour optimiser les coûts
- **Environnements** : Configurations pour développement et production

## Prérequis

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0+)
2. [Google Cloud SDK](https://cloud.google.com/sdk/install)
3. Compte GCP avec les API suivantes activées:
   - Compute Engine API
   - Kubernetes Engine API
   - IAM API

## Comment utiliser

### 1. Authentification

```bash
# Authentifiez-vous avec votre compte Google Cloud
gcloud auth login

# Configurez l'application des identifiants par défaut
gcloud auth application-default login
```

### 2. Déploiement

#### Environnement de développement

```bash
# Initialisez Terraform avec le backend de développement
terraform init -backend-config=backends/dev.config

# Planifiez le déploiement
terraform plan -var-file=envs/dev.tfvars

# Appliquez la configuration
terraform apply -var-file=envs/dev.tfvars
```

#### Environnement de production

```bash
# Initialisez Terraform avec le backend de production
terraform init -backend-config=backends/prd.config

# Planifiez le déploiement
terraform plan -var-file=envs/prd.tfvars

# Appliquez la configuration
terraform apply -var-file=envs/prd.tfvars
```

### 3. Accès au cluster

Après le déploiement, configurez kubectl pour accéder au cluster :

```bash
# Pour l'environnement de développement
gcloud container clusters get-credentials gke-dev-cluster --region europe-west9 --project caramel-abacus-472612-h3

# Pour l'environnement de production
gcloud container clusters get-credentials gke-prod-cluster --region europe-west9 --project epitech-vpc-demo-69
```

### 4. Déploiement de l'application (Cours 7)

Après avoir déployé le cluster, déployez votre application Task Manager :

```bash
# 1. Créez les secrets pour la base de données
kubectl create secret generic db-credentials \
  --from-literal=database=taskmanager \
  --from-literal=username=admin \
  --from-literal=password=VOTRE_MOT_DE_PASSE

# 2. Déployez l'application avec le HPA et le LoadBalancer
kubectl apply -f kubernetes_manifests_examples.yaml

# 3. Vérifiez le déploiement
kubectl get pods
kubectl get svc
kubectl get hpa

# 4. Obtenez l'IP externe du Load Balancer
kubectl get svc task-manager-service

# 5. Attendez que l'IP externe soit assignée (peut prendre 2-3 minutes)
# Puis testez : curl http://<EXTERNAL-IP>
```

### 5. Test du Scaling Horizontal (OBLIGATOIRE pour la défense)

Le Cours 7 exige de démontrer le scaling horizontal complet (pods + nœuds) :

```bash
# Surveillez le HPA en temps réel
kubectl get hpa -w

# Dans un autre terminal, surveillez les pods
kubectl get pods -w

# Dans un troisième terminal, surveillez les nœuds
kubectl get nodes -w

# Générez de la charge (load testing)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Dans le pod :
while true; do wget -q -O- http://task-manager-service; done

# Vous devriez observer :
# 1. CPU augmente sur les pods existants
# 2. HPA crée de nouveaux pods (1 → 6)
# 3. Si les nœuds sont pleins, Cluster Autoscaler ajoute des nœuds (1 → 5)
# 4. Nouveaux pods sont schedulés sur les nouveaux nœuds
```

**⚠️ Important pour la défense** :
- Préparez un script de load testing
- Démontrez le scaling des pods ET des nœuds
- Expliquez pourquoi vous avez choisi des petites instances
- Montrez que l'application retourne HTTP 429 en cas de surcharge

## Structure du projet

```
.
├── backends/             # Configurations des backends pour chaque environnement
├── envs/                 # Variables spécifiques aux environnements
├── basics_refresher.tf   # Configuration du provider Google
├── main.tf               # Configuration principale de Terraform
├── variables.tf          # Définition des variables
├── vpc_subnet.tf         # Configuration du réseau VPC
├── iam_kubernetes.tf     # Rôles IAM pour Kubernetes
├── kubernetes_cluster.tf # Configuration du cluster GKE
└── kubernetes_concepts.tf # Documentation sur les concepts Kubernetes
```

## Choix Architecturaux (pour la défense du projet)

### Pourquoi Mode Standard et pas Autopilot ?

**Mode Standard avec Node Pools** :
- ✅ Contrôle total sur le Cluster Autoscaler (exigence Cours 7)
- ✅ Configuration explicite du nombre de nœuds et des types de machines
- ✅ Permet de choisir des petites instances (e2-small/e2-medium) pour optimiser les coûts
- ✅ Facilite la démonstration du scaling horizontal complet
- ✅ Aligne avec les exigences pédagogiques des cours

**Autopilot** :
- ❌ Autoscaling caché et automatique (blackbox)
- ❌ Pas de contrôle sur les types de machines
- ❌ Difficile de démontrer le scaling pour la défense
- ❌ Ne permet pas de justifier les choix techniques

### Stratégie de Scaling (Cours 7)

1. **HPA (Horizontal Pod Autoscaler)** :
   - Min: 1 pod, Max: 6 pods
   - Seuil: 70% CPU, 80% mémoire
   - Scale up rapide (60s), scale down lent (5min)

2. **Cluster Autoscaler** :
   - Min: 1 nœud, Max: 5 nœuds
   - Petites instances (e2-small/medium)
   - Stratégie: 1-2 pods par nœud, puis scale les nœuds
   - Optimise les coûts (billing basé sur les nœuds)

3. **Séquence de scaling** :
   - Charge augmente → HPA crée des pods
   - Pods en "Pending" (pas de ressources) → Cluster Autoscaler ajoute des nœuds
   - Nouveaux nœuds prêts → Pods schedulés
   - Charge diminue → HPA réduit les pods → Cluster Autoscaler retire les nœuds

### Load Balancer : Option 1 vs Option 2

**Option 1 choisie : Kubernetes Service LoadBalancer**
- ✅ Intégration native avec Kubernetes
- ✅ Synchronisation automatique des backends (pods)
- ✅ Health checks automatiques
- ✅ Plus simple à gérer et à démontrer

**Option 2 : Cloud-Managed Load Balancer (Terraform)**
- ⚠️ Plus de contrôle mais plus complexe
- ⚠️ Synchronisation manuelle des backends
- ⚠️ Recommandé si intégration avec services non-Kubernetes

## Concepts de Kubernetes documentés

- **Cluster, Nodes & Control Plane** : Architecture de base de Kubernetes
- **Pods, Deployments & Services** : Ressources de base pour les applications
- **Node Pools** : Groupes de nœuds avec configuration homogène
- **HPA & Cluster Autoscaler** : Scaling horizontal à deux niveaux
- **Load Balancing** : Distribution du trafic et haute disponibilité
- **Network Policies** : Sécurité et isolation réseau
- **Probes** : Liveness et Readiness pour la haute disponibilité

## Maintenance

Pour mettre à jour le cluster ou modifier la configuration :

1. Modifiez les fichiers Terraform pertinents
2. Exécutez `terraform plan` pour voir les changements
3. Appliquez avec `terraform apply`

## Suppression

Pour supprimer toute l'infrastructure :

```bash
terraform destroy -var-file=envs/dev.tfvars  # Pour le développement
terraform destroy -var-file=envs/prd.tfvars  # Pour la production
```

⚠️ **Attention** : Cela supprimera toutes les ressources, y compris les données persistantes !
