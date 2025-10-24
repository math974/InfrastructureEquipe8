# Guide de Déploiement

## Architecture des Environnements

### Environnements GitHub

1. **development** - Environnement de développement
   - Branch: `develop`
   - URL: `https://tasks-app-dev.example.com`
   - Namespace: `tasks-dev`

2. **production** - Environnement de production
   - Branch: `main`
   - URL: `https://tasks-app.example.com`
   - Namespace: `tasks-prod`

## Workflows CI/CD

### 1. Test (test.yml)
- **Déclencheur**: PR sur `main` ou `develop`
- **Actions**:
  - Tests unitaires
  - Linting (flake8, black)
  - Scan de sécurité (Trivy)
  - Build test Docker

### 2. Déploiement DEV (deploy-dev.yml)
- **Déclencheur**: Push sur `develop`
- **Actions**:
  - Tests
  - Build et push vers GCR + GitHub Container Registry
  - Déploiement sur GKE avec Helm
  - Vérification

### 3. Déploiement PROD (deploy-prod.yml)
- **Déclencheur**: Push sur `main` ou tag `v*`
- **Actions**:
  - Tests complets
  - Scan de sécurité
  - Build et push vers registries
  - Déploiement sur GKE avec Helm
  - Tests de fumée

## Configuration des Secrets

### Secrets GitHub requis

```bash
# Google Cloud
GCP_PROJECT_ID=your-project-id
GCP_SA_KEY=base64-encoded-service-account-key
GKE_CLUSTER_NAME=your-cluster-name
GKE_ZONE=your-zone

# Base de données
DB_PASSWORD_DEV=dev-password
DB_PASSWORD_PROD=prod-password
```

### Configuration des environnements GitHub

1. Allez dans Settings > Environments
2. Créez les environnements `development` et `production`
3. Configurez les secrets pour chaque environnement
4. Activez la protection des branches si nécessaire

## Déploiement Manuel

### Avec le script
```bash
# Déploiement dev
./scripts/deploy.sh tasks-dev dev dev-latest

# Déploiement prod
./scripts/deploy.sh tasks-prod prod v1.0.0
```

### Avec Helm directement
```bash
# Dev
helm upgrade --install tasks-app-dev ./helm/tasks-app \
  --namespace tasks-dev \
  --create-namespace \
  --values ./helm/tasks-app/values-dev.yaml \
  --set image.tag=dev-latest

# Prod
helm upgrade --install tasks-app-prod ./helm/tasks-app \
  --namespace tasks-prod \
  --create-namespace \
  --values ./helm/tasks-app/values.yaml \
  --set image.tag=v1.0.0
```

## Monitoring et Debugging

### Vérifier les déploiements
```bash
# Pods
kubectl get pods -n tasks-dev
kubectl get pods -n tasks-prod

# Services
kubectl get services -n tasks-dev
kubectl get services -n tasks-prod

# Ingress
kubectl get ingress -n tasks-dev
kubectl get ingress -n tasks-prod

# Logs
kubectl logs -f deployment/tasks-app-dev -n tasks-dev
kubectl logs -f deployment/tasks-app-prod -n tasks-prod
```

### Rollback
```bash
# Rollback avec Helm
helm rollback tasks-app-dev -n tasks-dev
helm rollback tasks-app-prod -n tasks-prod

# Rollback avec kubectl
kubectl rollout undo deployment/tasks-app-dev -n tasks-dev
kubectl rollout undo deployment/tasks-app-prod -n tasks-prod
```

## Stratégie de Branches

- **`develop`** → Déploiement automatique en DEV
- **`main`** → Déploiement automatique en PROD
- **Tags `v*`** → Déploiement PROD avec version spécifique

## Sécurité

- Images scannées avec Trivy
- Secrets gérés via GitHub Secrets
- Utilisateur non-root dans les conteneurs
- Health checks configurés
- Ressources limitées
