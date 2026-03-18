resource "google_storage_bucket" "redmine" {
  name     = "${var.project_id}-redmine-attachments"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
}
