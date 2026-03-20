#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <project-id>"
  exit 1
fi

PROJECT_ID="$1"
REGION="${2:-asia-northeast1}"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/redmine/redmine:latest"
echo "==> Building Docker image"
docker build --platform linux/amd64 -t "${IMAGE}" .

echo "==> Pushing to Artifact Registry"
docker push "${IMAGE}"

echo "==> Updating Cloud Run service"
gcloud run services update redmine --region="${REGION}" --image="${IMAGE}"

echo ""
echo "==> Deployment complete!"
