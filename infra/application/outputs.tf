output "health_url" {
  value = "${google_cloud_run_v2_service.api.uri}/health"
}
output "migration_job" {
  value = google_cloud_run_v2_job.migration.name
}
output "deployed_commit" {
  value = var.commit_sha
}
