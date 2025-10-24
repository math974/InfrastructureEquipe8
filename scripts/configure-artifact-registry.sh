#!/bin/bash

# Script pour configurer Artifact Registry et les variables GitHub

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Configuration d'Artifact Registry${NC}"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "terraform" ]; then
    echo -e "${RED}❌ Le répertoire terraform/ n'existe pas.${NC}"
    echo "Assurez-vous d'être dans le répertoire racine du projet."
    exit 1
fi

# Aller dans le répertoire terraform
cd terraform

# Vérifier que Terraform est initialisé
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform n'est pas initialisé.${NC}"
    echo -e "${YELLOW}🔧 Initialisation de Terraform...${NC}"
    terraform init
fi

# Obtenir les informations d'Artifact Registry
echo -e "${YELLOW}🔍 Récupération des informations d'Artifact Registry...${NC}"

ARTIFACT_REGISTRY_URL=$(terraform output -raw artifact_registry_info 2>/dev/null | jq -r '.repository_url' 2>/dev/null || echo "")
ARTIFACT_REGISTRY_ID=$(terraform output -raw artifact_registry_info 2>/dev/null | jq -r '.repository_id' 2>/dev/null || echo "")
WRITER_SA=$(terraform output -raw artifact_registry_info 2>/dev/null | jq -r '.writer_service_account' 2>/dev/null || echo "")

if [ -z "$ARTIFACT_REGISTRY_URL" ]; then
    echo -e "${RED}❌ Impossible de récupérer les informations d'Artifact Registry.${NC}"
    echo "Assurez-vous que le module artifact-registry a été déployé avec succès."
    echo "Exécutez: terraform apply"
    exit 1
fi

echo -e "${GREEN}✅ Informations d'Artifact Registry récupérées !${NC}"
echo "  - URL: $ARTIFACT_REGISTRY_URL"
echo "  - ID: $ARTIFACT_REGISTRY_ID"
echo "  - Writer SA: $WRITER_SA"

# Retourner au répertoire parent
cd ..

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
echo "  - Artifact Registry URL: $ARTIFACT_REGISTRY_URL"
echo "  - Repository ID: $ARTIFACT_REGISTRY_ID"
echo "  - Writer Service Account: $WRITER_SA"
echo ""
echo -e "${YELLOW}💡 Les workflows GitHub Actions utiliseront maintenant Artifact Registry.${NC}"
echo -e "${YELLOW}💡 Vous pouvez maintenant pousser du code pour déclencher les workflows.${NC}"

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
echo -e "${GREEN}🎉 Artifact Registry est maintenant configuré !${NC}"
