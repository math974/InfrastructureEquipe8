# 🧹 Nettoyage du dossier Kubernetes

## ✅ **Fichiers supprimés :**

### **Application simple obsolète :**
- ❌ `kubernetes/simple-app/` (dossier complet)
  - `app.py`
  - `Dockerfile`
  - `k8s-deployment.yaml`
  - `requirements.txt`

### **Configuration obsolète :**
- ❌ `kubernetes/envs/` (dossier complet)
  - `dev.tfvars`
  - `prd.tfvars`

### **Scripts obsolètes :**
- ❌ `kubernetes/deploy-app.sh`
- ❌ `kubernetes/kubernetes_manifests_examples.yaml`
- ❌ `kubernetes/kubernetes_concepts.tf`
- ❌ `kubernetes/kubernetes_cluster.tf`
- ❌ `kubernetes/iam_kubernetes.tf` (déplacé vers module IAM)
- ❌ `kubernetes/README.md` (ancien)

## ✅ **Fichiers conservés :**

### **Infrastructure Kubernetes :**
- ✅ `kubernetes/main.tf` → Configuration du cluster GKE
- ✅ `kubernetes/variables.tf` → Variables du module
- ✅ `kubernetes/outputs.tf` → Outputs du module
- ✅ `kubernetes/load_test.sh` → Script de test de charge
- ✅ `kubernetes/README.md` → Documentation mise à jour

## 🎯 **Résultat :**

Le dossier `kubernetes/` contient maintenant uniquement :
- **Infrastructure GKE** (cluster, node pools, configuration réseau)
- **Scripts de test** (load testing)

L'application Task Manager API est maintenant dans `app/` avec :
- ✅ `app/Dockerfile` → Image Docker pour l'application
- ✅ `app/k8s-deployment.yaml` → Manifests Kubernetes
- ✅ `app/deploy-app.sh` → Script de déploiement

## 🚀 **Utilisation :**

### **Infrastructure :**
```bash
# Déploiement de l'infrastructure Kubernetes
./deploy-modular.sh dev
```

### **Application :**
```bash
# Déploiement de l'application
./app/deploy-app.sh dev YOUR_PROJECT_ID
```

## 📋 **Séparation claire :**

- **`kubernetes/`** → Infrastructure GKE uniquement
- **`app/`** → Application Task Manager API
- **`terraform/modules/`** → Modules réutilisables

La séparation des responsabilités est maintenant claire ! 🎉
