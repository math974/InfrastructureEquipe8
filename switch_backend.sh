#!/bin/bash

# Script pour changer de backend et de workspace Terraform

set -e

ENVIRONMENT=$1

if [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "prd" ]; then
  echo "Switching to $ENVIRONMENT workspace..."

  # Vérifie et sélectionne le workspace
  terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT

  echo "Successfully switched to $ENVIRONMENT workspace."
else
  echo "Usage: ./switch_backend.sh [dev|prd]"
  exit 1
fi
