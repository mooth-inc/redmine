resource "google_dns_managed_zone" "redmine" {
  name        = "redmine-zone"
  dns_name    = "${var.domain}."
  description = "Redmine managed zone"
  visibility  = "public"
}

resource "google_dns_record_set" "a" {
  name         = "${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.redmine.name
  rrdatas      = [var.ip_address]
}
