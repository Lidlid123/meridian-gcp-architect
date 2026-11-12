data "terraform_remote_state" "platform" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "meridian/platform"
  }
}

locals {
  p = data.terraform_remote_state.platform.outputs
  image = "${var.region}-docker.pkg.dev/${var.project_id}/${local.p.artifact_repository}/api:${var.commit_sha}"
  shared_env = {
    "GCP_PROJECT_ID"       = var.project_id
    "REGION"               = var.region
    "INSTANCE_CONNECTION_NAME" = local.p.db_instance_connection_name
    "DB_NAME"              = local.p.db_name
    "DB_USER"              = local.p.db_user
    "DB_PASSWORD_SECRET"   = "${local.p.db_password_secret}/versions/latest"
    "API_TOKEN_SECRET"     = "${local.p.api_token_secret}/versions/latest"
  }
}

resource "google_cloud_run_v2_service" "api" {
  name                = "meridian-api"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.p.runtime_service_account
    timeout         = "30s"
    max_instance_request_concurrency = 20
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    containers {
      image = local.image
      ports {
        container_port = 8080
      }
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
      dynamic "env" {
        for_each = merge(local.shared_env, {
          "CANDIDATE_NAME" = var.candidate_name
          "COMMIT_SHA"     = var.commit_sha
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = local.p.network_name
        subnetwork = local.p.subnet_name
        tags       = ["meridian-cloud-run"]
      }
    }
  }
}

# Only GET /health is implemented by the application. Never expose data endpoints publicly.
resource "google_cloud_run_v2_service_iam_member" "public_health_demo" {
  project  = var.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Authorized engineers can trigger private DB migrations using the Cloud Run API,
# without opening PostgreSQL to the internet or connecting their laptops to VPC.
resource "google_cloud_run_v2_job" "migration" {
  name                = "meridian-migrate"
  location            = var.region
  deletion_protection = false

  template {
    template {
      service_account = local.p.runtime_service_account
      timeout         = "300s"
      max_retries     = 0
      containers {
        image   = local.image
        command = ["python", "migrate.py"]
        dynamic "env" {
          for_each = local.shared_env
          content {
            name  = env.key
            value = env.value
          }
        }
      }
      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = local.p.network_name
          subnetwork = local.p.subnet_name
          tags       = ["meridian-cloud-run"]
        }
      }
    }
  }
}

# Optional, only after review is ready; repo users still must be separately granted
# access to execute the migration job. Never give the reviewer access to secrets.
resource "google_project_iam_member" "reviewer_viewer" {
  count   = var.reviewer_email == "" ? 0 : 1
  project = var.project_id
  role    = "roles/viewer"
  member  = "user:${var.reviewer_email}"
}
