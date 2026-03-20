PROJECT_ID ?= $(shell gcloud config get project 2>/dev/null)
REGION     ?= asia-northeast1
IMAGE      ?= $(REGION)-docker.pkg.dev/$(PROJECT_ID)/redmine/redmine:latest
BUCKET     ?= $(PROJECT_ID)-redmine-tfstate

ifndef PROJECT_ID
$(error PROJECT_ID is not set. Run 'gcloud config set project <id>' or pass PROJECT_ID=<id>)
endif

.PHONY: help up down logs build push tf-init tf-plan tf-apply tf-destroy tf-validate tf-fmt update-service deploy setup tf-output url secret-init secret-smtp

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- Local Development ---

up: ## Start local Redmine
	docker-compose up -d

down: ## Stop local Redmine
	docker-compose down

logs: ## Show Redmine logs
	docker-compose logs -f redmine

# --- Docker ---

build: ## Build Docker image
	docker build --platform linux/amd64 -t $(IMAGE) .

push: ## Push image to Artifact Registry
	docker push $(IMAGE)

# --- Terraform ---

tf-init: ## Initialize Terraform
	cd infra && terraform init -backend-config="bucket=$(BUCKET)"

tf-plan: ## Preview infrastructure changes
	cd infra && terraform plan -var="image=$(IMAGE)"

tf-apply: ## Apply infrastructure changes
	cd infra && terraform apply -var="image=$(IMAGE)"

tf-destroy: ## Destroy infrastructure
	cd infra && terraform destroy -var="image=$(IMAGE)"

tf-validate: ## Validate Terraform config
	cd infra && terraform validate

tf-fmt: ## Format Terraform files
	cd infra && terraform fmt -recursive

# --- Deployment ---

update-service: ## Update Cloud Run service image (no Terraform)
	gcloud run services update redmine --region=$(REGION) --image=$(IMAGE)

deploy: build push update-service ## Deploy app (build + push + update service)

setup: ## Run GCP initial setup
	./scripts/setup.sh $(PROJECT_ID) $(REGION)

# --- Secrets ---

secret-init: ## Auto-register secrets (DB password, secret key, GCS keys)
	./scripts/secret-init.sh $(PROJECT_ID)

secret-smtp: ## Register SMTP secrets in Secret Manager
	@echo "Enter SMTP domain:"; read val; echo -n "$$val" | gcloud secrets versions add redmine-smtp-domain --data-file=-
	@echo "Enter SMTP user:"; read val; echo -n "$$val" | gcloud secrets versions add redmine-smtp-user --data-file=-
	@echo "Enter SMTP password:"; read val; echo -n "$$val" | gcloud secrets versions add redmine-smtp-password --data-file=-

# --- Info ---

tf-output: ## Show Terraform outputs
	cd infra && terraform output

url: ## Show access URL
	@cd infra && terraform output service_url
