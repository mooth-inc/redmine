output "static_ip_address" {
  value       = module.load_balancer.static_ip_address
  description = "Global static IP address"
}

output "access_url" {
  value       = var.domain != "" ? "https://${var.domain}" : "http://${module.load_balancer.static_ip_address}"
  description = "URL to access Redmine"
}

output "dns_nameservers" {
  value       = var.domain != "" ? module.dns[0].nameservers : []
  description = "Cloud DNS nameservers. Update your domain registrar NS records to these values."
}

output "cloud_sql_user_password" {
  value     = module.cloud_sql.user_password
  sensitive = true
}
