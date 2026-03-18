locals {
  service_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/services/redmine?updateMask=scaling.minInstanceCount"
}

resource "google_cloud_scheduler_job" "warmup" {
  name      = "redmine-warmup"
  schedule  = var.warmup_schedule
  time_zone = "Asia/Tokyo"
  region    = var.region

  http_target {
    http_method = "PATCH"
    uri         = local.service_uri
    body        = base64encode(jsonencode({ scaling = { minInstanceCount = 1 } }))

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = var.scheduler_sa_email
    }
  }
}

resource "google_cloud_scheduler_job" "sleep" {
  name      = "redmine-sleep"
  schedule  = var.sleep_schedule
  time_zone = "Asia/Tokyo"
  region    = var.region

  http_target {
    http_method = "PATCH"
    uri         = local.service_uri
    body        = base64encode(jsonencode({ scaling = { minInstanceCount = 0 } }))

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = var.scheduler_sa_email
    }
  }
}
