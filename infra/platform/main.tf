locals {
  required_apis = toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
}

resource "google_project_service" "services" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "main" {
  name                    = "meridian-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "run" {
  name          = "meridian-run-subnet"
  ip_cidr_range = "10.40.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  private_ip_google_access = true
}

# Cloud SQL's managed private-IP address range is separate from the Cloud Run subnet.
resource "google_compute_global_address" "private_services" {
  name          = "meridian-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  address       = "10.64.0.0"
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  depends_on              = [google_project_service.services]
}

resource "random_id" "sql_suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "postgres" {
  name             = "meridian-pg-${random_id.sql_suffix.hex}"
  database_version = "POSTGRES_16"
  region           = var.region
  deletion_protection = false # Demo cleanup; use true in production.

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro" # Evaluation only: no SLA, not production-appropriate.
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = true

    backup_configuration {
      enabled = false # Cost-limited PoC only; mandatory in real production.
    }

    ip_configuration {
      ipv4_enabled       = false
      private_network    = google_compute_network.main.id
      allocated_ip_range = google_compute_global_address.private_services.name
    }

    deletion_protection_enabled = false
  }

  depends_on = [
    google_project_service.services,
    google_service_networking_connection.private_services,
  ]
}

resource "google_sql_database" "app" {
  name     = "meridian"
  instance = google_sql_database_instance.postgres.name
}

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = "meridian_app"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

resource "random_password" "sample_api_token" {
  length  = 40
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "meridian-db-password"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "api_token" {
  secret_id = "meridian-third-party-api-token"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  depends_on = [google_project_service.services]
}

# Demo-only token; replace through a controlled secret-management process in real life.
resource "google_secret_manager_secret_version" "api_token" {
  secret      = google_secret_manager_secret.api_token.id
  secret_data = random_password.sample_api_token.result
}

resource "google_service_account" "runtime" {
  account_id   = "meridian-api-runtime"
  display_name = "Meridian Cloud Run API and private migration job"
  depends_on   = [google_project_service.services]
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "api_token" {
  secret_id = google_secret_manager_secret.api_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = "meridian-api"
  format        = "DOCKER"
  description   = "Demo API image repository; images are built from Git commits"
  depends_on    = [google_project_service.services]
}
