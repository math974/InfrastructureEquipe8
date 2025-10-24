#!/bin/bash

# Script pour obtenir l'URL d'Artifact Registry et configurer GitHub

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Recherche de l'URL d'Artifact Registry${NC}"

# Vérifier que gcloud CLI est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud CLI (gcloud) n'est pas installé.${NC}"
    echo "Installation: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Vérifier que l'utilisateur est connecté à Google Cloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Vous n'êtes pas connecté à Google Cloud.${NC}"
    echo "Commande: gcloud auth login"
    exit 1
fi

# Obtenir le projet actuel
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Aucun projet Google Cloud configuré.${NC}"
    echo "Commande: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${YELLOW}📋 Projet: ${PROJECT_ID}${NC}"

# Rechercher les Artifact Registries
echo -e "${YELLOW}🔍 Recherche des Artifact Registries...${NC}"
ARTIFACT_REGISTRIES=$(gcloud artifacts repositories list --format="table(name,format,location)" --project=$PROJECT_ID 2>/dev/null || echo "")

if [ -z "$ARTIFACT_REGISTRIES" ] || [ "$ARTIFACT_REGISTRIES" = "NAME  FORMAT  LOCATION" ]; then
    echo -e "${RED}❌ Aucun Artifact Registry trouvé dans le projet ${PROJECT_ID}${NC}"
    echo "Assurez-vous que Terraform a été déployé avec succès."
    echo "Exécutez: terraform apply"
    exit 1
fi

echo -e "${GREEN}✅ Artifact Registries trouvés:${NC}"
echo "$ARTIFACT_REGISTRIES"

# Obtenir l'URL du premier registry Docker
echo -e "${YELLOW}🔍 Récupération de l'URL du registry Docker...${NC}"
ARTIFACT_REGISTRY_URL=$(gcloud artifacts repositories list --format="value(name)" --filter="format=DOCKER" --project=$PROJECT_ID | head -1)

if [ -z "$ARTIFACT_REGISTRY_URL" ]; then
    echo -e "${RED}❌ Aucun registry Docker trouvé.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Registry Docker trouvé: ${ARTIFACT_REGISTRY_URL}${NC}"

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

# Configuration des variables GitHub
echo -e "${YELLOW}🔧 Configuration des variables GitHub...${NC}"

# Variables pour l'environnement de développement
echo -e "${BLUE}📝 Configuration de l'environnement 'Develop'...${NC}"
gh variable set ARTIFACT_REGISTRY_URL --body="$ARTIFACT_REGISTRY_URL" --env=Develop
gh variable set REGISTRY --body="$ARTIFACT_REGISTRY_URL" --env=Develop
gh variable set IMAGE_NAME --body="tasks-app" --env=Develop
gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Develop

# Variables pour l'environnement de production
echo -e "${BLUE}📝 Configuration de l'environnement 'Production'...${NC}"
gh variable set ARTIFACT_REGISTRY_URL --body="$ARTIFACT_REGISTRY_URL" --env=Production
gh variable set REGISTRY --body="$ARTIFACT_REGISTRY_URL" --env=Production
gh variable set IMAGE_NAME --body="tasks-app" --env=Production
gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Production

echo -e "${GREEN}✅ Configuration terminée avec succès !${NC}"
echo ""
echo -e "${BLUE}📋 Résumé de la configuration:${NC}"
echo "  - Projet GCP: $PROJECT_ID"
echo "  - Artifact Registry URL: $ARTIFACT_REGISTRY_URL"
echo ""
echo -e "${YELLOW}💡 Les workflows GitHub Actions utiliseront maintenant Artifact Registry.${NC}"
echo -e "${YELLOW}💡 Le workflow deploy-dev.yml s'exécutera après terraform.yml.${NC}"

# Afficher les commandes Docker pour tester
echo ""
echo -e "${BLUE}🐳 Commandes Docker pour tester:${NC}"
echo "  # Authentification"
echo "  gcloud auth configure-docker $ARTIFACT_REGISTRY_URL"
echo ""
echo "  # Build et push d'une image de test"
echo "  docker build -t $ARTIFACT_REGISTRY_URL/test:latest ./app"
echo "  docker push $ARTIFACT_REGISTRY_URL/test:latest"
echo ""
echo -e "${GREEN}🎉 Configuration terminée !${NC}"
