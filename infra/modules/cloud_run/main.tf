resource "google_cloud_run_v2_service" "redmine" {
  name     = "redmine"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.service_account_email
    timeout         = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloud_sql_connection_name]
      }
    }

    containers {
      name  = "redmine"
      image = var.image

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      # Plain environment variables
      env {
        name  = "RAILS_ENV"
        value = "production"
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_HOST"
        value = "/cloudsql/${var.cloud_sql_connection_name}"
      }
      env {
        name  = "GCS_BUCKET_NAME"
        value = var.gcs_bucket_name
      }

      # Secret environment variables
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret
            version = "latest"
          }
        }
      }
      env {
        name = "REDMINE_SECRET_KEY_BASE"
        value_source {
          secret_key_ref {
            secret  = var.secret_key_base_secret
            version = "latest"
          }
        }
      }
      env {
        name = "GCS_ACCESS_KEY_ID"
        value_source {
          secret_key_ref {
            secret  = var.gcs_access_key_secret
            version = "latest"
          }
        }
      }
      env {
        name = "GCS_SECRET_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret  = var.gcs_secret_key_secret
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/"
          port = 3000
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.redmine.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
