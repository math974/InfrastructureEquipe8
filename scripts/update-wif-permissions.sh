#!/bin/bash

# Script pour mettre à jour les permissions du module bootstrap-wif
# et éviter de créer des registries par hasard

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Mise à jour des permissions WIF${NC}"

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
    echo -e "${YELLOW}⚠️  Terraform n'est pas initialisé.${NC}"
    echo -e "${YELLOW}🔧 Initialisation de Terraform...${NC}"
    terraform init
fi

# Vérifier l'état actuel
echo -e "${YELLOW}🔍 Vérification de l'état actuel...${NC}"
terraform plan

# Demander confirmation
echo -e "${YELLOW}🤔 Voulez-vous appliquer les changements ? (y/N)${NC}"
read -p "> " CONFIRM

if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🔧 Application des changements...${NC}"
    terraform apply -auto-approve
    
    echo -e "${GREEN}✅ Permissions mises à jour avec succès !${NC}"
    
    # Afficher les nouvelles informations
    echo -e "${BLUE}📋 Nouvelles informations:${NC}"
    WIF_PROVIDER=$(terraform output -raw workload_identity_provider_name)
    SA_EMAIL=$(terraform output -raw service_account_email)
    
    echo "  - WIF Provider: $WIF_PROVIDER"
    echo "  - Service Account: $SA_EMAIL"
    
    echo -e "${YELLOW}💡 Vous pouvez maintenant configurer GitHub avec ces informations.${NC}"
    echo -e "${YELLOW}💡 Utilisez: ./scripts/get-wif-info.sh${NC}"
else
    echo -e "${YELLOW}❌ Mise à jour annulée.${NC}"
fi

# Retourner au répertoire parent
cd ..

echo -e "${GREEN}🎉 Script terminé !${NC}"
