#!/bin/bash

# Script de déploiement avec Helm
set -e

# Configuration
NAMESPACE=${1:-tasks-app}
ENVIRONMENT=${2:-dev}
IMAGE_TAG=${3:-latest}
CHART_PATH="./helm/tasks-app"
VALUES_FILE="values-${ENVIRONMENT}.yaml"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl n'est pas installé"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm n'est pas installé"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    
    log "Prérequis OK"
}

# Créer le namespace si nécessaire
create_namespace() {
    log "Création du namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
}

# Déployer avec Helm
deploy_with_helm() {
    log "Déploiement avec Helm..."
    
    local release_name="tasks-app-${ENVIRONMENT}"
    local values_file="${CHART_PATH}/${VALUES_FILE}"
    
    if [ ! -f "${values_file}" ]; then
        warn "Fichier de valeurs ${values_file} non trouvé, utilisation des valeurs par défaut"
        values_file="${CHART_PATH}/values.yaml"
    fi
    
    log "Release: ${release_name}"
    log "Namespace: ${NAMESPACE}"
    log "Image tag: ${IMAGE_TAG}"
    log "Values file: ${values_file}"
    
    helm upgrade --install ${release_name} ${CHART_PATH} \
        --namespace ${NAMESPACE} \
        --create-namespace \
        --values ${values_file} \
        --set image.tag=${IMAGE_TAG} \
        --wait \
        --timeout=10m
    
    log "Déploiement terminé"
}

# Vérifier le déploiement
verify_deployment() {
    log "Vérification du déploiement..."
    
    # Attendre que les pods soient prêts
    kubectl wait --for=condition=available --timeout=300s deployment/tasks-app-${ENVIRONMENT} -n ${NAMESPACE} || {
        error "Le déploiement n'est pas prêt dans les temps"
        kubectl get pods -n ${NAMESPACE}
        exit 1
    }
    
    # Afficher les ressources
    log "Pods:"
    kubectl get pods -n ${NAMESPACE}
    
    log "Services:"
    kubectl get services -n ${NAMESPACE}
    
    log "Ingress:"
    kubectl get ingress -n ${NAMESPACE}
    
    log "Déploiement vérifié avec succès"
}

# Fonction principale
main() {
    log "Démarrage du déploiement..."
    log "Environnement: ${ENVIRONMENT}"
    log "Namespace: ${NAMESPACE}"
    log "Image tag: ${IMAGE_TAG}"
    
    check_prerequisites
    create_namespace
    deploy_with_helm
    verify_deployment
    
    log "Déploiement terminé avec succès!"
}

# Aide
show_help() {
    echo "Usage: $0 [NAMESPACE] [ENVIRONMENT] [IMAGE_TAG]"
    echo ""
    echo "Arguments:"
    echo "  NAMESPACE    Namespace Kubernetes (défaut: tasks-app)"
    echo "  ENVIRONMENT  Environnement (dev/prod) (défaut: dev)"
    echo "  IMAGE_TAG    Tag de l'image Docker (défaut: latest)"
    echo ""
    echo "Exemples:"
    echo "  $0                           # Déploiement dev par défaut"
    echo "  $0 tasks-prod prod v1.0.0    # Déploiement prod avec tag v1.0.0"
    echo "  $0 tasks-dev dev dev-latest  # Déploiement dev avec tag dev-latest"
}

# Gestion des arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Exécuter le script principal
main
