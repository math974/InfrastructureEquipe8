# Module Kubernetes - Infrastructure GKE

Ce module Terraform déploie uniquement l'infrastructure Kubernetes (cluster GKE) sans application.

## 🏗️ **Ce que ce module fait :**

- **Cluster GKE** : Cluster Kubernetes géré avec autoscaling
- **Node Pools** : Pools de nœuds avec auto-repair et auto-upgrade
- **Configuration réseau** : Intégration avec le VPC existant
- **Permissions IAM** : Gérées par le module IAM

## 📁 **Structure :**

```
kubernetes/
├── main.tf              # Configuration du cluster GKE
├── variables.tf         # Variables du module
├── outputs.tf           # Outputs du module
└── load_test.sh         # Script de test de charge
```

## 🚀 **Déploiement :**

Ce module est déployé automatiquement via l'architecture modulaire :

```bash
# Déploiement complet (network + iam + kubernetes)
./deploy-modular.sh dev
./deploy-modular.sh prd
```

## 📱 **Application :**

L'application Task Manager API est déployée séparément depuis le dossier `app/` :

```bash
# Déploiement de l'application
./app/deploy-app.sh dev YOUR_PROJECT_ID
./app/deploy-app.sh prd YOUR_PROJECT_ID
```

## 🔧 **Configuration :**

Les variables sont configurées dans :
- `environments/dev/terraform.tfvars`
- `environments/prd/terraform.tfvars`

## 📊 **Monitoring :**

```bash
# Vérifier le cluster
gcloud container clusters get-credentials gke-cluster-dev --region europe-west9 --project YOUR_PROJECT_ID
kubectl get nodes
kubectl get pods --all-namespaces
```

## 🎯 **Résultat :**

Ce module fournit uniquement l'infrastructure Kubernetes. L'application est déployée séparément pour une meilleure séparation des responsabilités.
