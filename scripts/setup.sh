#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <project-id>"
  exit 1
fi

PROJECT_ID="$1"
REGION="${2:-asia-northeast1}"
BUCKET_NAME="${PROJECT_ID}-redmine-tfstate"
REPO_NAME="redmine"

echo "==> Setting project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Creating GCS bucket for Terraform state: ${BUCKET_NAME}"
gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --location="${REGION}" \
  --uniform-bucket-level-access \
  2>/dev/null || echo "Bucket already exists"

echo "==> Enabling Artifact Registry API"
gcloud services enable artifactregistry.googleapis.com

echo "==> Creating Artifact Registry repository: ${REPO_NAME}"
gcloud artifacts repositories create "${REPO_NAME}" \
  --repository-format=docker \
  --location="${REGION}" \
  2>/dev/null || echo "Repository already exists"

echo "==> Configuring Docker authentication"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Copy and edit terraform.tfvars:"
echo "     cp infra/terraform.tfvars.example infra/terraform.tfvars"
echo ""
echo "  2. Build image and provision infrastructure:"
echo "     make init PROJECT_ID=${PROJECT_ID}"
echo "     make deploy PROJECT_ID=${PROJECT_ID}"
echo ""
echo "  3. Register secrets (requires resources created by step 2):"
echo "     make secret-init   # Auto-register DB password, secret key, GCS keys"
echo "     make secret-smtp   # Register SMTP secrets interactively"
echo ""
echo "  4. Re-deploy so Cloud Run picks up the secret values:"
echo "     make deploy PROJECT_ID=${PROJECT_ID}"
