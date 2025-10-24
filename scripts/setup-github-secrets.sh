#!/bin/bash

# Script pour configurer les secrets GitHub pour les workflows CI/CD
# Ce script doit être exécuté après le déploiement Terraform

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Configuration des secrets GitHub pour les workflows CI/CD${NC}"

# Vérifier que gh CLI est installé
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) n'est pas installé. Veuillez l'installer d'abord.${NC}"
    echo "Installation: https://cli.github.com/"
    exit 1
fi

# Vérifier que l'utilisateur est connecté à GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Vous n'êtes pas connecté à GitHub CLI. Veuillez vous connecter d'abord.${NC}"
    echo "Commande: gh auth login"
    exit 1
fi

# Vérifier que gcloud CLI est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud CLI (gcloud) n'est pas installé. Veuillez l'installer d'abord.${NC}"
    echo "Installation: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Vérifier que l'utilisateur est connecté à Google Cloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Vous n'êtes pas connecté à Google Cloud. Veuillez vous connecter d'abord.${NC}"
    echo "Commande: gcloud auth login"
    exit 1
fi

# Obtenir les informations du projet
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Aucun projet Google Cloud configuré. Veuillez configurer un projet.${NC}"
    echo "Commande: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${YELLOW}📋 Configuration pour le projet: ${PROJECT_ID}${NC}"

# Obtenir les informations du cluster GKE
echo -e "${YELLOW}🔍 Recherche des clusters GKE...${NC}"
CLUSTERS=$(gcloud container clusters list --format="value(name,location)" --project=$PROJECT_ID)

if [ -z "$CLUSTERS" ]; then
    echo -e "${RED}❌ Aucun cluster GKE trouvé dans le projet ${PROJECT_ID}${NC}"
    exit 1
fi

# Afficher les clusters disponibles
echo -e "${YELLOW}📋 Clusters GKE disponibles:${NC}"
echo "$CLUSTERS"

# Demander à l'utilisateur de choisir le cluster
echo -e "${YELLOW}🤔 Veuillez choisir le cluster pour l'environnement de développement:${NC}"
read -p "Nom du cluster: " CLUSTER_NAME
read -p "Région du cluster: " CLUSTER_REGION

# Obtenir les informations du service account GitHub Actions depuis bootstrap-wif
echo -e "${YELLOW}🔍 Recherche du service account GitHub Actions...${NC}"
SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:GitHub Terraform" --format="value(email)" --project=$PROJECT_ID)

if [ -z "$SA_EMAIL" ]; then
    echo -e "${RED}❌ Service account GitHub Actions non trouvé.${NC}"
    echo "Assurez-vous que le module bootstrap-wif/ a été déployé avec succès."
    exit 1
fi

echo -e "${GREEN}✅ Service account trouvé: ${SA_EMAIL}${NC}"

# Obtenir les informations Workload Identity Federation
echo -e "${YELLOW}🔍 Recherche de la configuration Workload Identity Federation...${NC}"
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers list --location=global --format="value(name)" --project=$PROJECT_ID | head -1)

if [ -z "$WIF_PROVIDER" ]; then
    echo -e "${RED}❌ Workload Identity Federation non configuré.${NC}"
    echo "Veuillez d'abord configurer WIF avec le module bootstrap-wif/"
    exit 1
fi

echo -e "${GREEN}✅ WIF Provider trouvé: ${WIF_PROVIDER}${NC}"

# Configuration des secrets GitHub
echo -e "${YELLOW}🔧 Configuration des secrets GitHub...${NC}"

# Secrets pour l'environnement de développement
echo -e "${YELLOW}📝 Configuration des secrets pour l'environnement 'Develop'...${NC}"

gh secret set GCP_PROJECT_ID --body="$PROJECT_ID" --env=Develop
gh secret set GKE_CLUSTER_NAME --body="$CLUSTER_NAME" --env=Develop
gh secret set GKE_ZONE --body="$CLUSTER_REGION" --env=Develop
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body="$WIF_PROVIDER" --env=Develop
gh secret set GCP_SERVICE_ACCOUNT --body="$SA_EMAIL" --env=Develop

# Variables pour l'environnement de développement
echo -e "${YELLOW}📝 Configuration des variables pour l'environnement 'Develop'...${NC}"

gh variable set REGISTRY --body="gcr.io" --env=Develop
gh variable set IMAGE_NAME --body="tasks-app" --env=Develop
gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Develop

# Secrets pour l'environnement de production
echo -e "${YELLOW}📝 Configuration des secrets pour l'environnement 'Production'...${NC}"

gh secret set GCP_PROJECT_ID --body="$PROJECT_ID" --env=Production
gh secret set GKE_CLUSTER_NAME --body="$CLUSTER_NAME" --env=Production
gh secret set GKE_ZONE --body="$CLUSTER_REGION" --env=Production
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body="$WIF_PROVIDER" --env=Production
gh secret set GCP_SERVICE_ACCOUNT --body="$SA_EMAIL" --env=Production

# Variables pour l'environnement de production
echo -e "${YELLOW}📝 Configuration des variables pour l'environnement 'Production'...${NC}"

gh variable set REGISTRY --body="gcr.io" --env=Production
gh variable set IMAGE_NAME --body="tasks-app" --env=Production
gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Production

echo -e "${GREEN}✅ Configuration terminée avec succès !${NC}"
echo -e "${YELLOW}📋 Résumé de la configuration:${NC}"
echo "  - Projet GCP: $PROJECT_ID"
echo "  - Cluster GKE: $CLUSTER_NAME ($CLUSTER_REGION)"
echo "  - Service Account: $SA_EMAIL"
echo "  - WIF Provider: $WIF_PROVIDER"
echo ""
echo -e "${GREEN}🎉 Les workflows CI/CD sont maintenant configurés !${NC}"
echo -e "${YELLOW}💡 Vous pouvez maintenant pousser du code pour déclencher les workflows.${NC}"