output "service_url" {
  value       = module.cloud_run.service_uri
  description = "Cloud Run service URL"
}

output "iap_client_id" {
  value       = google_iap_client.redmine.client_id
  description = "IAP client ID"
}

output "cloud_sql_user_password" {
  value     = module.cloud_sql.user_password
  sensitive = true
}
