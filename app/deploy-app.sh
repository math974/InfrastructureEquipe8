#!/usr/bin/env bash
set -euo pipefail

# Script pour déployer l'application Task Manager API sur le cluster GKE
# Usage: ./deploy-app.sh [dev|prd] [PROJECT_ID]

ENVIRONMENT=${1:-dev}
PROJECT_ID=${2:-""}

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 [dev|prd] [PROJECT_ID]"
    echo "Example: $0 dev my-dev-project-123"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="gke-cluster-${ENVIRONMENT}"
REGION="europe-west9"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }

log "🚀 Déploiement de l'application Task Manager API sur l'environnement: ${ENVIRONMENT}"

# 1. Construire et pousser l'image Docker
log "🔨 Construction de l'image Docker..."
cd "${ROOT_DIR}"

# Construire l'image
docker build -t gcr.io/${PROJECT_ID}/task-manager-api:latest .

# Pousser l'image vers Google Container Registry
log "📤 Push de l'image vers GCR..."
docker push gcr.io/${PROJECT_ID}/task-manager-api:latest

# 2. Configurer kubectl pour le cluster
log "⚙️  Configuration de kubectl pour le cluster ${CLUSTER_NAME}..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

# 3. Déployer l'application
log "🚀 Déploiement de l'application sur Kubernetes..."

# Remplacer PROJECT_ID dans le manifest
sed "s/PROJECT_ID/${PROJECT_ID}/g" k8s-deployment.yaml > k8s-deployment-${ENVIRONMENT}.yaml

# Appliquer les manifests
kubectl apply -f k8s-deployment-${ENVIRONMENT}.yaml

# 4. Vérifier le déploiement
log "✅ Vérification du déploiement..."
kubectl get pods -l app=task-manager-api
kubectl get services
kubectl get ingress

# 5. Attendre que les pods soient prêts
log "⏳ Attente que les pods soient prêts..."
kubectl rollout status deployment/task-manager-api

# 6. Obtenir l'URL de l'application
log "🌐 Récupération de l'URL de l'application..."
INGRESS_IP=$(kubectl get ingress task-manager-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "En cours de création...")

log "✅ Déploiement terminé !"
log ""
log "📋 Informations de l'application :"
log "  • API Documentation: http://${INGRESS_IP}/docs"
log "  • ReDoc: http://${INGRESS_IP}/redoc"
log "  • Health Check: http://${INGRESS_IP}/docs"
log ""
log "🧪 Pour tester l'application :"
log "  kubectl port-forward service/task-manager-api-service 8000:80"
log "  curl http://localhost:8000/docs"
log ""
log "📊 Pour surveiller :"
log "  kubectl logs -l app=task-manager-api"
log "  kubectl get pods -l app=task-manager-api"
