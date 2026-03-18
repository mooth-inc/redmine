PROJECT_ID ?= your-project-id
REGION     ?= asia-northeast1
IMAGE      ?= $(REGION)-docker.pkg.dev/$(PROJECT_ID)/redmine/redmine:latest
BUCKET     ?= $(PROJECT_ID)-redmine-tfstate

.PHONY: help up down logs build push init plan apply destroy validate fmt deploy setup output url

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# --- Local Development ---

up: ## Start local Redmine
	docker-compose up -d

down: ## Stop local Redmine
	docker-compose down

logs: ## Show Redmine logs
	docker-compose logs -f redmine

# --- Docker ---

build: ## Build Docker image
	docker build -t $(IMAGE) .

push: ## Push image to Artifact Registry
	docker push $(IMAGE)

# --- Terraform ---

init: ## Initialize Terraform
	cd infra && terraform init -backend-config="bucket=$(BUCKET)"

plan: ## Preview infrastructure changes
	cd infra && terraform plan -var="image=$(IMAGE)"

apply: ## Apply infrastructure changes
	cd infra && terraform apply -var="image=$(IMAGE)"

destroy: ## Destroy infrastructure
	cd infra && terraform destroy -var="image=$(IMAGE)"

validate: ## Validate Terraform config
	cd infra && terraform validate

fmt: ## Format Terraform files
	cd infra && terraform fmt -recursive

# --- Deployment ---

deploy: build push apply ## Full deploy (build + push + apply)

setup: ## Run GCP initial setup
	./scripts/setup.sh $(PROJECT_ID) $(REGION)

# --- Info ---

output: ## Show Terraform outputs
	cd infra && terraform output

url: ## Show access URL
	@cd infra && terraform output access_url
