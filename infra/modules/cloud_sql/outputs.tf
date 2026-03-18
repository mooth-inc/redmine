output "connection_name" {
  value = google_sql_database_instance.redmine.connection_name
}

output "database_name" {
  value = google_sql_database.redmine.name
}

output "user_name" {
  value = google_sql_user.redmine.name
}

output "user_password" {
  value     = random_password.db_password.result
  sensitive = true
}
