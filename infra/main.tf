terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    prefix = "redmine/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------- API Enablement ----------

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ---------- Service Accounts ----------

resource "google_service_account" "cloudrun" {
  account_id   = "redmine-run-sa"
  display_name = "Redmine Cloud Run Service Account"
}

resource "google_service_account" "scheduler" {
  account_id   = "redmine-scheduler-sa"
  display_name = "Redmine Scheduler Service Account"
}

# ---------- IAM: Cloud Run SA ----------

resource "google_project_iam_member" "cloudrun_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "cloudrun_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# ---------- IAM: Scheduler SA ----------

resource "google_project_iam_member" "scheduler_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_service_account_iam_member" "scheduler_act_as_self" {
  service_account_id = google_service_account.scheduler.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.scheduler.email}"
}

# ---------- Secret Manager ----------

locals {
  secrets = {
    "redmine-db-password"       = "Database password for Redmine"
    "redmine-secret-key-base"   = "Rails secret key base"
    "redmine-gcs-access-key"    = "GCS interoperability access key"
    "redmine-gcs-secret-key"    = "GCS interoperability secret key"
  }
}

resource "google_secret_manager_secret" "secrets" {
  for_each  = local.secrets
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

# ---------- Modules ----------

module "cloud_sql" {
  source = "./modules/cloud_sql"

  project_id = var.project_id
  region     = var.region
  db_tier    = var.db_tier

  depends_on = [google_project_service.apis["sqladmin.googleapis.com"]]
}

module "gcs" {
  source = "./modules/gcs"

  project_id = var.project_id
  region     = var.region
}

resource "google_storage_bucket_iam_member" "cloudrun_gcs" {
  bucket = module.gcs.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun.email}"
}

module "cloud_run" {
  source = "./modules/cloud_run"

  project_id                = var.project_id
  region                    = var.region
  image                     = var.image
  cpu                       = var.cloudrun_cpu
  memory                    = var.cloudrun_memory
  max_instances             = var.cloudrun_max_instances
  service_account_email     = google_service_account.cloudrun.email
  cloud_sql_connection_name = module.cloud_sql.connection_name
  db_name                   = module.cloud_sql.database_name
  db_user                   = module.cloud_sql.user_name
  db_password_secret        = google_secret_manager_secret.secrets["redmine-db-password"].secret_id
  secret_key_base_secret    = google_secret_manager_secret.secrets["redmine-secret-key-base"].secret_id
  gcs_bucket_name           = module.gcs.bucket_name
  gcs_access_key_secret     = google_secret_manager_secret.secrets["redmine-gcs-access-key"].secret_id
  gcs_secret_key_secret     = google_secret_manager_secret.secrets["redmine-gcs-secret-key"].secret_id

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
    google_project_iam_member.cloudrun_cloudsql,
    google_project_iam_member.cloudrun_secretmanager,
    google_storage_bucket_iam_member.cloudrun_gcs,
  ]
}

module "load_balancer" {
  source = "./modules/load_balancer"

  region       = var.region
  domain       = var.domain
  service_name = module.cloud_run.service_name

  depends_on = [google_project_service.apis["compute.googleapis.com"]]
}

module "dns" {
  source = "./modules/dns"
  count  = var.domain != "" ? 1 : 0

  domain     = var.domain
  ip_address = module.load_balancer.static_ip_address

  depends_on = [google_project_service.apis["dns.googleapis.com"]]
}

module "scheduler" {
  source = "./modules/scheduler"

  project_id             = var.project_id
  region                 = var.region
  warmup_schedule        = var.warmup_schedule
  sleep_schedule         = var.sleep_schedule
  scheduler_sa_email     = google_service_account.scheduler.email

  depends_on = [
    google_project_service.apis["cloudscheduler.googleapis.com"],
    module.cloud_run,
  ]
}
