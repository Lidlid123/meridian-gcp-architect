output "region" {
  value = var.region
}
output "network_name" {
  value = google_compute_network.main.name
}
output "subnet_name" {
  value = google_compute_subnetwork.run.name
}
output "runtime_service_account" {
  value = google_service_account.runtime.email
}
output "db_instance_connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}
output "db_name" {
  value = google_sql_database.app.name
}
output "db_user" {
  value = google_sql_user.app.name
}
output "db_password_secret" {
  value = google_secret_manager_secret.db_password.id
}
output "api_token_secret" {
  value = google_secret_manager_secret.api_token.id
}
output "artifact_repository" {
  value = google_artifact_registry_repository.api.repository_id
}
