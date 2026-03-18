output "nameservers" {
  value = google_dns_managed_zone.redmine.name_servers
}
