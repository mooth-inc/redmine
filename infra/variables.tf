variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "domain" {
  type        = string
  default     = ""
  description = "Domain name (e.g. redmine.example.com). Empty = HTTP only. Set to enable HTTPS, DNS, and redirect."
}

variable "image" {
  type        = string
  description = "Docker image URL for Redmine (e.g. asia-northeast1-docker.pkg.dev/PROJECT/redmine/redmine:latest)"
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "cloudrun_cpu" {
  type    = string
  default = "1"
}

variable "cloudrun_memory" {
  type    = string
  default = "512Mi"
}

variable "cloudrun_max_instances" {
  type    = number
  default = 3
}

variable "warmup_schedule" {
  type        = string
  default     = "0 8 * * 1-5"
  description = "Cron schedule to set min-instances=1 (Asia/Tokyo)"
}

variable "sleep_schedule" {
  type        = string
  default     = "0 20 * * 1-5"
  description = "Cron schedule to set min-instances=0 (Asia/Tokyo)"
}
