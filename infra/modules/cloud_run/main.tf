resource "google_cloud_run_v2_service" "redmine" {
  name                = "redmine"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  iap_enabled         = true

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
      env {
        name = "SMTP_DOMAIN"
        value_source {
          secret_key_ref {
            secret  = var.smtp_domain_secret
            version = "latest"
          }
        }
      }
      env {
        name = "SMTP_USER"
        value_source {
          secret_key_ref {
            secret  = var.smtp_user_secret
            version = "latest"
          }
        }
      }
      env {
        name = "SMTP_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.smtp_password_secret
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 10
        failure_threshold     = 18
        timeout_seconds       = 3
      }
    }
  }
}

# IAP service agent needs run.invoker to forward authenticated requests
resource "google_cloud_run_v2_service_iam_member" "iap_service_agent" {
  name     = google_cloud_run_v2_service.redmine.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com"
}

# Workaround: google_iap_web_cloud_run_service_iam_binding has a known bug (#23092)
# where bindings apply successfully but don't take effect at the IAP layer.
resource "terraform_data" "iap_access_binding" {
  triggers_replace = [
    google_cloud_run_v2_service.redmine.name,
    join(",", var.iap_allowed_members),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      for MEMBER in ${join(" ", var.iap_allowed_members)}; do
        gcloud beta iap web add-iam-policy-binding \
          --project=${var.project_id} \
          --resource-type=cloud-run \
          --service=${google_cloud_run_v2_service.redmine.name} \
          --region=${var.region} \
          --member="$MEMBER" \
          --role="roles/iap.httpsResourceAccessor" \
          --quiet
      done
    EOT
  }
}
