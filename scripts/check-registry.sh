#!/bin/bash

# Script pour vérifier l'existence des registries et éviter d'en créer par hasard

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Vérification des registries existants${NC}"

# Obtenir le projet actuel
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Aucun projet Google Cloud configuré.${NC}"
    echo "Commande: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${YELLOW}📋 Projet: ${PROJECT_ID}${NC}"

# Vérifier Google Container Registry (GCR)
echo -e "${YELLOW}🔍 Vérification de Google Container Registry (GCR)...${NC}"
GCR_BUCKETS=$(gcloud storage buckets list --filter="name:artifacts.${PROJECT_ID}.appspot.com" --format="value(name)" 2>/dev/null || echo "")

if [ -n "$GCR_BUCKETS" ]; then
    echo -e "${GREEN}✅ GCR bucket trouvé: ${GCR_BUCKETS}${NC}"
else
    echo -e "${YELLOW}⚠️  Aucun bucket GCR trouvé.${NC}"
    echo "Le bucket GCR sera créé automatiquement lors du premier push d'image."
fi

# Vérifier Artifact Registry
echo -e "${YELLOW}🔍 Vérification d'Artifact Registry...${NC}"
ARTIFACT_REGISTRIES=$(gcloud artifacts repositories list --format="value(name)" --project=$PROJECT_ID 2>/dev/null || echo "")

if [ -n "$ARTIFACT_REGISTRIES" ]; then
    echo -e "${GREEN}✅ Artifact Registries trouvés:${NC}"
    echo "$ARTIFACT_REGISTRIES"
else
    echo -e "${YELLOW}⚠️  Aucun Artifact Registry trouvé.${NC}"
    echo "Vous pouvez en créer un si nécessaire avec:"
    echo "gcloud artifacts repositories create REPO_NAME --repository-format=docker --location=LOCATION"
fi

# Vérifier les permissions du service account
echo -e "${YELLOW}🔍 Vérification des permissions du service account...${NC}"

# Obtenir le service account GitHub Actions
SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:GitHub Terraform" --format="value(email)" --project=$PROJECT_ID)

if [ -z "$SA_EMAIL" ]; then
    echo -e "${RED}❌ Service account GitHub Actions non trouvé.${NC}"
    echo "Assurez-vous que le module bootstrap-wif/ a été déployé."
    exit 1
fi

echo -e "${GREEN}✅ Service account trouvé: ${SA_EMAIL}${NC}"

# Vérifier les permissions IAM
echo -e "${YELLOW}🔍 Vérification des permissions IAM...${NC}"

# Vérifier les permissions sur le projet
IAM_POLICY=$(gcloud projects get-iam-policy $PROJECT_ID --format="json" 2>/dev/null || echo "{}")

# Vérifier les permissions spécifiques
STORAGE_ADMIN=$(echo "$IAM_POLICY" | jq -r ".bindings[] | select(.role == \"roles/storage.admin\") | .members[] | select(. == \"serviceAccount:${SA_EMAIL}\")" 2>/dev/null || echo "")
CONTAINER_ADMIN=$(echo "$IAM_POLICY" | jq -r ".bindings[] | select(.role == \"roles/container.admin\") | .members[] | select(. == \"serviceAccount:${SA_EMAIL}\")" 2>/dev/null || echo "")
ARTIFACT_ADMIN=$(echo "$IAM_POLICY" | jq -r ".bindings[] | select(.role == \"roles/artifactregistry.admin\") | .members[] | select(. == \"serviceAccount:${SA_EMAIL}\")" 2>/dev/null || echo "")

if [ -n "$STORAGE_ADMIN" ]; then
    echo -e "${GREEN}✅ Permission storage.admin accordée${NC}"
else
    echo -e "${RED}❌ Permission storage.admin manquante${NC}"
fi

if [ -n "$CONTAINER_ADMIN" ]; then
    echo -e "${GREEN}✅ Permission container.admin accordée${NC}"
else
    echo -e "${RED}❌ Permission container.admin manquante${NC}"
fi

if [ -n "$ARTIFACT_ADMIN" ]; then
    echo -e "${GREEN}✅ Permission artifactregistry.admin accordée${NC}"
else
    echo -e "${YELLOW}⚠️  Permission artifactregistry.admin manquante${NC}"
    echo "Cette permission sera ajoutée lors du prochain déploiement Terraform."
fi

echo ""
echo -e "${BLUE}📋 Résumé:${NC}"
echo "  - Projet: $PROJECT_ID"
echo "  - Service Account: $SA_EMAIL"
echo "  - GCR Bucket: ${GCR_BUCKETS:-'Sera créé automatiquement'}"
echo "  - Artifact Registries: ${ARTIFACT_REGISTRIES:-'Aucun'}"
echo ""

if [ -n "$STORAGE_ADMIN" ] && [ -n "$CONTAINER_ADMIN" ]; then
    echo -e "${GREEN}✅ Les permissions de base sont configurées.${NC}"
    echo -e "${YELLOW}💡 Vous pouvez maintenant tester le push d'images.${NC}"
else
    echo -e "${RED}❌ Des permissions manquent.${NC}"
    echo -e "${YELLOW}💡 Redéployez le module bootstrap-wif/ avec: terraform apply${NC}"
fi
