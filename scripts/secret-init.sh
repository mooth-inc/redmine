#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <project-id>"
  exit 1
fi

PROJECT_ID="$1"
SA_EMAIL="redmine-run-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if a secret already has at least one version
has_version() {
  local secret="$1"
  gcloud secrets versions list "$secret" --project="$PROJECT_ID" --limit=1 --format="value(name)" 2>/dev/null | grep -q .
}

# Add a secret version from stdin value
add_secret() {
  local secret="$1"
  local value="$2"
  echo -n "$value" | gcloud secrets versions add "$secret" --project="$PROJECT_ID" --data-file=-
}

# --- redmine-db-password ---
echo "==> redmine-db-password"
if has_version "redmine-db-password"; then
  echo "    Already has a version, skipping."
else
  DB_PASSWORD=$(cd infra && terraform output -raw cloud_sql_user_password)
  add_secret "redmine-db-password" "$DB_PASSWORD"
  echo "    Registered from terraform output."
fi

# --- redmine-secret-key-base ---
echo "==> redmine-secret-key-base"
if has_version "redmine-secret-key-base"; then
  echo "    Already has a version, skipping."
else
  SECRET_KEY=$(openssl rand -hex 64)
  add_secret "redmine-secret-key-base" "$SECRET_KEY"
  echo "    Generated and registered."
fi

# --- redmine-gcs-access-key / redmine-gcs-secret-key ---
echo "==> redmine-gcs-access-key / redmine-gcs-secret-key"
if has_version "redmine-gcs-access-key" && has_version "redmine-gcs-secret-key"; then
  echo "    Already have versions, skipping."
else
  echo "    Creating HMAC key for ${SA_EMAIL}..."
  HMAC_OUTPUT=$(gcloud storage hmac create "$SA_EMAIL" --project="$PROJECT_ID" --format="json")
  GCS_ACCESS_KEY=$(echo "$HMAC_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['metadata']['accessId'])")
  GCS_SECRET_KEY=$(echo "$HMAC_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['secret'])")
  add_secret "redmine-gcs-access-key" "$GCS_ACCESS_KEY"
  add_secret "redmine-gcs-secret-key" "$GCS_SECRET_KEY"
  echo "    Registered HMAC access key and secret key."
fi

echo ""
echo "Done! SMTP secrets are not managed by this script."
echo "Use 'make secret-smtp' to register SMTP secrets interactively."
