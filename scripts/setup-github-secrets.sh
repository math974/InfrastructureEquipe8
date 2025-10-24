#!/bin/bash

# Script pour configurer les secrets GitHub Actions
set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    if ! command -v terraform &> /dev/null; then
        error "Terraform n'est pas installé"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI n'est pas installé"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI n'est pas authentifié"
        exit 1
    fi
    
    log "Prérequis OK"
}

# Récupérer les informations Terraform
get_terraform_outputs() {
    log "Récupération des outputs Terraform..."
    
    cd terraform
    
    # Initialiser Terraform si nécessaire
    if [ ! -d ".terraform" ]; then
        log "Initialisation de Terraform..."
        terraform init -backend-config=../configs/dev.config
    fi
    
    # Récupérer les outputs
    PROJECT_ID=$(terraform output -raw deployment_info | jq -r '.project_id')
    CLUSTER_NAME=$(terraform output -raw deployment_info | jq -r '.cluster_name')
    REGION=$(terraform output -raw deployment_info | jq -r '.region')
    INSTANCE_NAME="tasks-mysql"
    
    cd ../bootstrap-wif
    
    # Récupérer les informations WIF
    if [ ! -d ".terraform" ]; then
        log "Initialisation de bootstrap-wif..."
        terraform init -backend-config=../configs/bootstrap-wif-dev.config
    fi
    
    WIF_PROVIDER=$(terraform output -raw workload_identity_provider)
    WIF_SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
    
    cd ..
    
    log "Informations récupérées:"
    info "Project ID: $PROJECT_ID"
    info "Cluster: $CLUSTER_NAME"
    info "Region: $REGION"
    info "Instance Name: $INSTANCE_NAME"
    info "WIF Provider: $WIF_PROVIDER"
    info "Service Account: $WIF_SERVICE_ACCOUNT"
}

# Configurer les secrets GitHub
setup_github_secrets() {
    log "Configuration des secrets GitHub..."
    
    # Secrets pour l'environnement development
    log "Configuration de l'environnement 'development'..."
    gh secret set GCP_PROJECT_ID --body "$PROJECT_ID" --env development
    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "$WIF_PROVIDER" --env development
    gh secret set GCP_SERVICE_ACCOUNT --body "$WIF_SERVICE_ACCOUNT" --env development
    gh secret set GKE_CLUSTER_NAME --body "$CLUSTER_NAME" --env development
    gh secret set GKE_ZONE --body "$REGION" --env development
    
    # Secrets pour l'environnement production
    log "Configuration de l'environnement 'production'..."
    gh secret set GCP_PROJECT_ID --body "$PROJECT_ID" --env production
    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "$WIF_PROVIDER" --env production
    gh secret set GCP_SERVICE_ACCOUNT --body "$WIF_SERVICE_ACCOUNT" --env production
    gh secret set GKE_CLUSTER_NAME --body "$CLUSTER_NAME" --env production
    gh secret set GKE_ZONE --body "$REGION" --env production
    
    log "Secrets configurés avec succès"
}

# Afficher les informations de configuration
show_configuration_info() {
    log "Configuration terminée !"
    echo ""
    info "=== INFORMATIONS DE CONFIGURATION ==="
    echo ""
    info "Project ID: $PROJECT_ID"
    info "Cluster: $CLUSTER_NAME"
    info "Region: $REGION"
    info "WIF Provider: $WIF_PROVIDER"
    info "Service Account: $WIF_SERVICE_ACCOUNT"
    echo ""
    warn "=== ACTIONS REQUISES ==="
    echo ""
    warn "1. Les mots de passe de base de données sont gérés automatiquement"
    warn "   via Google Secret Manager (${INSTANCE_NAME}-app-db-password)"
    echo ""
    warn "2. Configurez les environnements GitHub:"
    warn "   - Allez dans Settings > Environments"
    warn "   - Créez les environnements 'development' et 'production'"
    warn "   - Configurez les protection rules si nécessaire"
    echo ""
    warn "3. Testez le déploiement:"
    warn "   - Push sur une branche (sauf main) → Déploiement DEV"
    warn "   - Push sur main → Déploiement PROD"
    echo ""
    log "Configuration terminée avec succès !"
}

# Fonction principale
main() {
    log "Démarrage de la configuration GitHub Actions..."
    
    check_prerequisites
    get_terraform_outputs
    setup_github_secrets
    show_configuration_info
}

# Aide
show_help() {
    echo "Usage: $0"
    echo ""
    echo "Ce script configure automatiquement les secrets GitHub Actions"
    echo "pour le déploiement sur Google Cloud Platform."
    echo ""
    echo "Prérequis:"
    echo "  - Terraform configuré et déployé"
    echo "  - GitHub CLI installé et authentifié"
    echo "  - Accès au repository GitHub"
}

# Gestion des arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Exécuter le script principal
main
