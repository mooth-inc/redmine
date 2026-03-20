resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "redmine" {
  name             = "redmine"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = false
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }

  deletion_protection = true
}

resource "google_sql_database" "redmine" {
  name     = "redmine"
  instance = google_sql_database_instance.redmine.name
}

resource "google_sql_user" "redmine" {
  name     = "redmine"
  instance = google_sql_database_instance.redmine.name
  password = random_password.db_password.result
}
