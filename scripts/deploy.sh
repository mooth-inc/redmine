#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <project-id>"
  exit 1
fi

PROJECT_ID="$1"
REGION="${2:-asia-northeast1}"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/redmine/redmine:latest"
BUCKET_NAME="${PROJECT_ID}-redmine-tfstate"

echo "==> Building Docker image"
docker build -t "${IMAGE}" .

echo "==> Pushing to Artifact Registry"
docker push "${IMAGE}"

echo "==> Running terraform init"
cd infra
terraform init -backend-config="bucket=${BUCKET_NAME}"

echo "==> Running terraform apply"
terraform apply -var="image=${IMAGE}"

echo ""
echo "==> Deployment complete!"
echo ""
terraform output access_url

DOMAIN=$(terraform output -raw access_url 2>/dev/null || true)
if echo "${DOMAIN}" | grep -q "https://"; then
  echo ""
  echo "DNS Nameservers (update your domain registrar):"
  terraform output dns_nameservers
fi
