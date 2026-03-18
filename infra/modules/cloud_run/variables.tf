variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "cpu" {
  type = string
}

variable "memory" {
  type = string
}

variable "max_instances" {
  type = number
}

variable "service_account_email" {
  type = string
}

variable "cloud_sql_connection_name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password_secret" {
  type = string
}

variable "secret_key_base_secret" {
  type = string
}

variable "gcs_bucket_name" {
  type = string
}

variable "gcs_access_key_secret" {
  type = string
}

variable "gcs_secret_key_secret" {
  type = string
}
