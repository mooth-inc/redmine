output "static_ip_address" {
  value = google_compute_global_address.redmine.address
}
