output "warmup_job_name" {
  value = google_cloud_scheduler_job.warmup.name
}

output "sleep_job_name" {
  value = google_cloud_scheduler_job.sleep.name
}
