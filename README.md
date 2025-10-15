<<<<<<< HEAD
# InfrastructureEquipe8

End-to-end Infrastructure as Code (IaC) on Google Cloud using Terraform. This project provisions:
- Networking (a VPC and a Subnet) per environment.
- Project IAM bindings for team members and an instructor per environment.
- Two environments managed with Terraform workspaces: `dev` and `prd`.
- Remote Terraform state stored in GCS buckets, configured per environment.

## Repository layout

- `netwoks/` — Terraform for networking
  - `main.tf` — Terraform and provider constraints + backend declaration
  - `basics_refresher.tf` — Google provider configuration
  - `vpc_subnet.tf` — VPC and Subnet resources
  - `variables.tf` — Variables for network module
  - `envs/` — Per-environment variables files (`dev.tfvars`, `prd.tfvars`)
- `iam/` — Terraform for IAM bindings
  - `main.tf` — Terraform and provider constraints + backend declaration
  - `provider.tf` — Google provider configuration
  - `variables.tf` — Variables for IAM module
  - `invite.tf` — IAM bindings for team members and instructor
  - `members.tf` — Outputs summary
  - `envs/` — Per-environment variables files (`dev.tfvars`, `prd.tfvars`)
- `configs/` — Backend config files for remote state
  - `dev.config`, `prd.config` — contain backend `bucket` and `prefix`
- `deploy_all.sh` — Deploys networking then IAM for both `dev` and `prd`
- `destroy_all.sh` — Destroys IAM then networking for both `prd` and `dev`
- `docs/` — Project documentation (md/pdf)

Note: the `netwoks` directory name is intentional; use it exactly as written in commands and paths.

## Prerequisites

- Terraform >= 1.5.0
- Google Cloud SDK (`gcloud`) and `gsutil`
- Access to Google Cloud project(s) with permissions to:
  - Create/modify VPC networking (Compute)
  - Manage IAM bindings on the project
  - Read/write to the GCS state bucket(s)
- Authentication:
  - Use Application Default Credentials (recommended): `gcloud auth application-default login`
  - Or set `GOOGLE_APPLICATION_CREDENTIALS` to a service account JSON with required permissions
- Enable required APIs in the target project(s):
  - `compute.googleapis.com`
  - `cloudresourcemanager.googleapis.com`
  - `iam.googleapis.com`
- Remote state buckets:
  - Ensure buckets defined in `configs/dev.config` and `configs/prd.config` exist and are unique globally.
  - Example create (adjust project/region/class as needed): `gsutil mb -p <project_id> -c STANDARD -l <region> gs://<bucket-name>`

## Environment configuration

- Networking (`netwoks/envs/*.tfvars`) — example values:
  - `project_id` — GCP project ID (e.g., `caramel-abacus-472612-h3`)
  - `region` — GCP region (e.g., `europe-west9`)
  - `network_name` — VPC name (e.g., `network-dev`, `network-prod`)
  - `ip_range` — Subnet CIDR (e.g., `10.0.0.0/20` for dev)

- IAM (`iam/envs/*.tfvars`) — example values:
  - `project_id` — GCP project ID (e.g., `caramel-abacus-472612-h3`)
  - `region` — GCP region (required by the provider, e.g., `europe-west9`)
  - `team_member_emails` — list of team emails
  - `team_role` — role for team (e.g., `roles/editor`)
  - `instructor_email` — instructor email
  - `instructor_role` — instructor role (e.g., `roles/viewer`)

Important: ensure `iam/envs/dev.tfvars` and `iam/envs/prd.tfvars` include a `region` value. The IAM provider reads `var.region`.

- Remote state backend configs (`configs/*.config`):
  - `bucket` — GCS bucket name (must exist)
  - `prefix` — base path for state; the scripts automatically append the module name (e.g., `vpc/netwoks` and `vpc/iam`)

## One-time setup checklist

1. Authenticate: `gcloud auth application-default login`
2. Create state buckets for dev/prd (or update `configs/*.config` to point to your buckets).
3. Confirm API enablement on the target project(s).
4. Verify/adjust values in:
   - `netwoks/envs/dev.tfvars` and `netwoks/envs/prd.tfvars`
   - `iam/envs/dev.tfvars` and `iam/envs/prd.tfvars` (ensure `region` exists)
   - `configs/dev.config` and `configs/prd.config`

## Deploy everything (end-to-end)

1. Make scripts executable (first time): `chmod +x deploy_all.sh destroy_all.sh`
2. Run: `./deploy_all.sh`

What happens:
- For each module (`netwoks`, then `iam`) and each environment (`dev`, then `prd`):
  - Initializes Terraform with the appropriate backend config and state prefix.
  - Selects or creates the workspace (`dev` or `prd`).
  - Applies using the corresponding `envs/*.tfvars`.

Resources created:
- `netwoks`: a custom-mode VPC and one Subnet per environment.
- `iam`: project-level IAM bindings for team members and optionally the instructor, plus an output summary.

## Destroy everything (clean up)

Run: `./destroy_all.sh`

What happens:
- Destroys IAM first (`prd` then `dev`), then networking (`prd` then `dev`), reusing the same backend configuration logic.

## Operating modules manually (optional)

If you want to run Terraform manually per module/environment:

- Networking (example: `dev`):
  - Change dir: `cd netwoks`
  - Init backend: `terraform init -reconfigure -backend-config=../configs/dev.config -backend-config=prefix=vpc/netwoks`
  - Workspace: `terraform workspace select dev || terraform workspace new dev`
  - Apply: `terraform apply -var-file=envs/dev.tfvars`

- IAM (example: `dev`):
  - Change dir: `cd iam`
  - Init backend: `terraform init -reconfigure -backend-config=../configs/dev.config -backend-config=prefix=vpc/iam`
  - Workspace: `terraform workspace select dev || terraform workspace new dev`
  - Apply: `terraform apply -var-file=envs/dev.tfvars`

Tip: You can pass transient overrides with environment variables like `TF_VAR_region=europe-west9`.

## Troubleshooting

- Missing region in IAM:
  - Error similar to "variable region is not set" — add `region = "<your-region>"` to `iam/envs/*.tfvars` or export `TF_VAR_region`.

- Backend bucket not found:
  - Error mentioning bucket does not exist — create the bucket or correct `configs/*.config` to point to an existing one.

- Permission or auth errors (403/401):
  - Ensure you have sufficient IAM roles on the target project(s).
  - Verify ADC (`gcloud auth application-default login`) or `GOOGLE_APPLICATION_CREDENTIALS` path.

- API not enabled:
  - Enable `compute.googleapis.com`, `cloudresourcemanager.googleapis.com`, and `iam.googleapis.com`.

- Bucket naming:
  - GCS bucket names are global; rename in `configs/*.config` if the provided names are taken.

## Notes

- The modules use Terraform workspaces (`dev`, `prd`) plus per-environment `*.tfvars`.
- Remote state prefix is derived from the `prefix` in `configs/*.config` and the module name; you can safely share buckets between modules with a unique prefix.
- IAM bindings are defined in `iam/invite.tf`. The `iam/members.tf` file emits a summary output.
- Provider versions:
  - Terraform `>= 1.5.0`
  - Google provider `>= 5.0`

## Quick reference

- Deploy all: `./deploy_all.sh`
- Destroy all: `./destroy_all.sh`
- Update only one env/module manually: run Terraform inside `netwoks/` or `iam/` with the appropriate workspace and `-var-file`.
=======
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
>>>>>>> github-action
