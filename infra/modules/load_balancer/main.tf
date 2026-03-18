resource "google_compute_global_address" "redmine" {
  name = "redmine-ip"
}

resource "google_compute_region_network_endpoint_group" "redmine" {
  name                  = "redmine-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = var.service_name
  }
}

resource "google_compute_backend_service" "redmine" {
  name                  = "redmine-backend"
  protocol              = "HTTP"
  timeout_sec           = 300
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.redmine.id
  }
}

# Main URL Map: routes to backend service
resource "google_compute_url_map" "main" {
  name            = "redmine-url-map"
  default_service = google_compute_backend_service.redmine.id
}

# Redirect URL Map: HTTP -> HTTPS 301 (only used when domain is set)
resource "google_compute_url_map" "redirect" {
  count = var.domain != "" ? 1 : 0
  name  = "redmine-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

# HTTP Proxy: points to main URL Map when no domain, redirect URL Map when domain is set
resource "google_compute_target_http_proxy" "redmine" {
  name    = "redmine-http-proxy"
  url_map = var.domain != "" ? google_compute_url_map.redirect[0].id : google_compute_url_map.main.id
}

# HTTP Forwarding Rule (always created)
resource "google_compute_global_forwarding_rule" "http" {
  name       = "redmine-http"
  target     = google_compute_target_http_proxy.redmine.id
  port_range = "80"
  ip_address = google_compute_global_address.redmine.address
}

# ---------- HTTPS resources (domain != "" only) ----------

resource "google_compute_managed_ssl_certificate" "redmine" {
  count = var.domain != "" ? 1 : 0
  name  = "redmine-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "redmine" {
  count            = var.domain != "" ? 1 : 0
  name             = "redmine-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.redmine[0].id]
}

resource "google_compute_global_forwarding_rule" "https" {
  count      = var.domain != "" ? 1 : 0
  name       = "redmine-https"
  target     = google_compute_target_https_proxy.redmine[0].id
  port_range = "443"
  ip_address = google_compute_global_address.redmine.address
}
