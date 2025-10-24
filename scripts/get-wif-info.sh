#!/bin/bash

# Script pour obtenir les informations du module bootstrap-wif
# et afficher les valeurs nécessaires pour configurer GitHub

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Informations du module bootstrap-wif${NC}"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "bootstrap-wif" ]; then
    echo -e "${RED}❌ Le répertoire bootstrap-wif/ n'existe pas.${NC}"
    echo "Assurez-vous d'être dans le répertoire racine du projet."
    exit 1
fi

# Aller dans le répertoire bootstrap-wif
cd bootstrap-wif

# Vérifier que Terraform est initialisé
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform n'est pas initialisé dans bootstrap-wif/${NC}"
    echo "Exécutez d'abord: terraform init"
    exit 1
fi

# Obtenir les outputs
echo -e "${YELLOW}📋 Récupération des informations du module WIF...${NC}"

WIF_PROVIDER=$(terraform output -raw workload_identity_provider_name 2>/dev/null || echo "")
SA_EMAIL=$(terraform output -raw service_account_email 2>/dev/null || echo "")

if [ -z "$WIF_PROVIDER" ] || [ -z "$SA_EMAIL" ]; then
    echo -e "${RED}❌ Impossible de récupérer les informations du module WIF.${NC}"
    echo "Assurez-vous que le module bootstrap-wif/ a été déployé avec succès."
    echo "Exécutez: terraform apply"
    exit 1
fi

# Obtenir les informations du projet
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Aucun projet Google Cloud configuré.${NC}"
    echo "Commande: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# Afficher les informations
echo -e "${GREEN}✅ Informations récupérées avec succès !${NC}"
echo ""
echo -e "${BLUE}📋 Configuration GitHub Actions:${NC}"
echo "  - Projet GCP: $PROJECT_ID"
echo "  - Service Account: $SA_EMAIL"
echo "  - WIF Provider: $WIF_PROVIDER"
echo ""

# Afficher les commandes pour configurer GitHub
echo -e "${YELLOW}🔧 Commandes pour configurer GitHub:${NC}"
echo ""
echo -e "${BLUE}# Secrets pour l'environnement 'Develop':${NC}"
echo "gh secret set GCP_PROJECT_ID --body=\"$PROJECT_ID\" --env=Develop"
echo "gh secret set GCP_SERVICE_ACCOUNT --body=\"$SA_EMAIL\" --env=Develop"
echo "gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body=\"$WIF_PROVIDER\" --env=Develop"
echo ""
echo -e "${BLUE}# Variables pour l'environnement 'Develop':${NC}"
echo "gh variable set REGISTRY --body=\"gcr.io\" --env=Develop"
echo "gh variable set IMAGE_NAME --body=\"tasks-app\" --env=Develop"
echo "gh variable set INSTANCE_NAME --body=\"tasks-mysql\" --env=Develop"
echo ""
echo -e "${BLUE}# Secrets pour l'environnement 'Production':${NC}"
echo "gh secret set GCP_PROJECT_ID --body=\"$PROJECT_ID\" --env=Production"
echo "gh secret set GCP_SERVICE_ACCOUNT --body=\"$SA_EMAIL\" --env=Production"
echo "gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body=\"$WIF_PROVIDER\" --env=Production"
echo ""
echo -e "${BLUE}# Variables pour l'environnement 'Production':${NC}"
echo "gh variable set REGISTRY --body=\"gcr.io\" --env=Production"
echo "gh variable set IMAGE_NAME --body=\"tasks-app\" --env=Production"
echo "gh variable set INSTANCE_NAME --body=\"tasks-mysql\" --env=Production"
echo ""

# Demander si l'utilisateur veut exécuter automatiquement
echo -e "${YELLOW}🤔 Voulez-vous exécuter automatiquement ces commandes ? (y/N)${NC}"
read -p "> " AUTO_EXECUTE

if [[ $AUTO_EXECUTE =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🔧 Exécution automatique des commandes...${NC}"
    
    # Secrets pour Develop
    echo -e "${BLUE}📝 Configuration de l'environnement 'Develop'...${NC}"
    gh secret set GCP_PROJECT_ID --body="$PROJECT_ID" --env=Develop
    gh secret set GCP_SERVICE_ACCOUNT --body="$SA_EMAIL" --env=Develop
    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body="$WIF_PROVIDER" --env=Develop
    gh variable set REGISTRY --body="gcr.io" --env=Develop
    gh variable set IMAGE_NAME --body="tasks-app" --env=Develop
    gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Develop
    
    # Secrets pour Production
    echo -e "${BLUE}📝 Configuration de l'environnement 'Production'...${NC}"
    gh secret set GCP_PROJECT_ID --body="$PROJECT_ID" --env=Production
    gh secret set GCP_SERVICE_ACCOUNT --body="$SA_EMAIL" --env=Production
    gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body="$WIF_PROVIDER" --env=Production
    gh variable set REGISTRY --body="gcr.io" --env=Production
    gh variable set IMAGE_NAME --body="tasks-app" --env=Production
    gh variable set INSTANCE_NAME --body="tasks-mysql" --env=Production
    
    echo -e "${GREEN}✅ Configuration terminée avec succès !${NC}"
else
    echo -e "${YELLOW}💡 Copiez et exécutez les commandes ci-dessus pour configurer GitHub.${NC}"
fi

# Retourner au répertoire parent
cd ..

echo -e "${GREEN}🎉 Les workflows CI/CD sont maintenant prêts !${NC}"
