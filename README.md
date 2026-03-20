# Redmine on Cloud Run

Run Redmine 5.1.x on Google Cloud Run with IAP authentication, Cloud SQL (PostgreSQL), GCS (attachments), and Cloud Scheduler (cold start mitigation), all managed by Terraform.

## Architecture

```
Internet → IAP Authentication → Cloud Run (*.run.app)
  Cloud Run → Cloud SQL (Unix socket via Cloud SQL volume)
            → GCS (S3-compatible API)
            → Secret Manager
  Cloud Scheduler → min-instances toggle (warmup/sleep)
```

## Prerequisites

- Google Cloud SDK (`gcloud`)
- Terraform >= 1.5
- Docker
- GNU Make

## Quick Start

```bash
# 1. Initial GCP setup (state bucket + Artifact Registry)
make setup PROJECT_ID=<project-id>

# 2. Configure terraform.tfvars
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars with your project_id, image, and iap_allowed_members

# 3. Provision infrastructure (first time only)
make tf-init PROJECT_ID=<project-id>
make tf-apply PROJECT_ID=<project-id>

# 4. Register secrets (requires resources created by step 3)
make secret-init   # Auto-register DB password, secret key, GCS keys
make secret-smtp   # Register SMTP secrets interactively

# 5. Deploy app (build + push + update Cloud Run service)
make deploy PROJECT_ID=<project-id>
```

## Make Targets

Run `make help` to list all targets.

| Target | Description |
|--------|-------------|
| `make up` | Start local Redmine with docker-compose |
| `make down` | Stop local Redmine |
| `make logs` | Tail Redmine container logs |
| `make build` | Build Docker image |
| `make push` | Push image to Artifact Registry |
| `make tf-init` | Initialize Terraform backend |
| `make tf-plan` | Preview infrastructure changes |
| `make tf-apply` | Apply infrastructure changes |
| `make tf-destroy` | Destroy infrastructure |
| `make tf-validate` | Validate Terraform config |
| `make tf-fmt` | Format Terraform files |
| `make update-service` | Update Cloud Run service image (no Terraform) |
| `make deploy` | Deploy app (build + push + update service) |
| `make secret-init` | Auto-register secrets (DB password, secret key, GCS keys) |
| `make secret-smtp` | Register SMTP secrets in Secret Manager |
| `make setup` | Run initial GCP setup |
| `make tf-output` | Show Terraform outputs |
| `make url` | Show access URL |

Override variables via the command line:

```bash
make deploy PROJECT_ID=my-project REGION=us-central1
```

## Security Notes

Cloud Run `ingress` is currently set to `INGRESS_TRAFFIC_ALL` to allow IAP-authenticated access without a Load Balancer. This means the Cloud Run service URL is publicly reachable. While IAP enforces authentication, direct access to the Cloud Run URL could allow HTTP header spoofing (e.g., `X-Forwarded-User`).

For stricter security, consider adding a Cloud Load Balancer and changing ingress to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`. See [Cloud Run ingress settings](https://cloud.google.com/run/docs/securing/ingress) for details.

## Plugins

### redmine_header_auth

HTTP header authentication plugin for automatic login via IAP-authenticated user identity. Added as a Git submodule.

Plugin migrations run automatically on container startup via `docker-entrypoint-custom.sh`.

To configure the plugin, go to **Administration > Plugins > Http Header Auth plugin > Configure** in the Redmine admin panel.

### redmine_omniauth_google

Google OAuth plugin for Redmine 5.x. Allows users to log in with their Google account and auto-registers new users.

Added as a Git submodule from [mosa11aei/redmine5.x-google-oauth](https://github.com/mosa11aei/redmine5.x-google-oauth).

After cloning, initialize submodules:

```bash
git submodule update --init
```

#### Setup

1. Create an OAuth 2.0 Client ID in [GCP Console > APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials)
   - Application type: Web application
   - Authorized redirect URI: `https://<your-redmine-domain>/oauth2callback`
2. Deploy the updated Docker image
3. In Redmine, go to **Administration > Plugins > Redmine Omniauth Google > Configure**
   - Enter Client ID and Client Secret
   - Enable "Oauth authentication"
   - (Optional) Set allowed email domain
4. Go to **Administration > Settings > Authentication** and enable self-registration (for auto-registration of new users)

## IAP Access

Access is controlled by Identity-Aware Proxy (IAP). Only members listed in `iap_allowed_members` can access the application.

Configure allowed members in `terraform.tfvars`:

```hcl
iap_allowed_members = [
  "user:alice@example.com",
  "user:bob@example.com",
  "group:team@example.com",
  "domain:example.com",
]
```

After deployment, access Redmine at the Cloud Run service URL:

```bash
make url
```

## Custom Domain

To use a custom domain, add a Cloud Run domain mapping manually (not managed by Terraform):

```bash
gcloud run domain-mappings create \
  --service=redmine \
  --domain=redmine.example.com \
  --region=asia-northeast1

# Follow the DNS verification instructions printed by the command
```

## Secret Registration

Terraform creates the Secret Manager secret resources, but values must be registered separately. After `make tf-apply`, run:

```bash
make secret-init   # Auto-register DB password, secret key, GCS keys
make secret-smtp   # Register SMTP secrets interactively
```

`make secret-init` automatically generates and registers the following secrets (idempotent — skips if already set):

| Secret | Method |
|--------|--------|
| `redmine-db-password` | Retrieved from `terraform output` |
| `redmine-secret-key-base` | Generated via `openssl rand -hex 64` |
| `redmine-gcs-access-key` | Generated via `gcloud storage hmac create` for Cloud Run SA |
| `redmine-gcs-secret-key` | Same HMAC key pair as above |

SMTP secrets require external service credentials and must be registered manually:

| Secret | Description |
|--------|-------------|
| `redmine-smtp-domain` | SMTP domain for email delivery |
| `redmine-smtp-user` | SMTP user for email delivery |
| `redmine-smtp-password` | SMTP password for email delivery |

```bash
make secret-smtp
```

## Local Development

```bash
make up
# Redmine: http://localhost:3000 (default login: admin / admin)
# Mailpit: http://localhost:8025 (captures all outgoing emails)

make logs   # Tail logs
make down   # Stop
```

## Deploy

```bash
make deploy PROJECT_ID=<project-id>
```

This runs `build` → `push` → `update-service` in sequence (no Terraform).

To run each step individually:

```bash
make build PROJECT_ID=<project-id>
make push  PROJECT_ID=<project-id>
make update-service PROJECT_ID=<project-id>   # Update Cloud Run image
```

For infrastructure changes, use the Terraform targets:

```bash
make tf-plan  PROJECT_ID=<project-id>   # Preview changes
make tf-apply PROJECT_ID=<project-id>   # Apply changes
```

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| Cloud Run | ~$1-3 |
| Cloud SQL (db-f1-micro) | ~$8-10 |
| GCS | ~$0.5 |
| **Total** | **~$10-14/month** |

## Scheduler Verification

Check scheduler job status:

```bash
# List jobs
gcloud scheduler jobs list --location=asia-northeast1

# Manually trigger warmup
gcloud scheduler jobs run redmine-warmup --location=asia-northeast1

# Verify min-instances changed
gcloud run services describe redmine --region=asia-northeast1 --format='value(spec.template.spec.containerConcurrency)'
```

## Troubleshooting

### IAP returns 403
Verify the user is included in `iap_allowed_members` in `terraform.tfvars` and re-apply:
```bash
make tf-apply PROJECT_ID=<project-id>
```

### Cold start is slow
Cloud Scheduler sets `min-instances=1` at 08:00 JST on weekdays. Check:
```bash
gcloud scheduler jobs describe redmine-warmup --location=asia-northeast1
```

### Database connection errors
- Verify Cloud SQL instance is running: `gcloud sql instances list`
- Check Cloud Run logs: `gcloud run services logs read redmine --region=asia-northeast1`
- Verify secret values are registered: `gcloud secrets versions list redmine-db-password`

### Attachments not uploading
- Verify GCS interoperability keys are registered in Secret Manager
- Check bucket exists: `gcloud storage ls gs://<project-id>-redmine-attachments`

