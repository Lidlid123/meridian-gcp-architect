# Meridian Payments — GCP Architect Exercise

## Architecture

A lightweight Python API deployed on **Google Cloud Run**, connected to a private **Cloud SQL PostgreSQL** database.

Infrastructure is provisioned using **Terraform** with remote state stored in GCS.

**Components:**
- Cloud Run — Public `/health` API
- Cloud SQL — Private PostgreSQL database
- Secret Manager — Database password and API token
- Custom VPC — Private network connectivity
- Cloud Run Job — On-demand database schema migrations
- Artifact Registry — Docker image storage

**Region:** `europe-west1` (Belgium)

## Key Architecture Decisions

- **Cloud Run over GKE:** Simpler and cost-effective for a single API.
- **Custom VPC:** Better network isolation than the default VPC.
- **Private Cloud SQL:** No public database access.
- **Cloud Run Job:** Developers can trigger migrations without direct database connectivity.
- **Security:** IAM-based access and no long-lived service account keys.

## Deployment

Requirements: Terraform, Google Cloud CLI, Docker, Git, and a GCP project with billing enabled.

Authenticate:

```powershell
gcloud auth login
gcloud auth application-default login
```

Follow `SETUP-WINDOWS.md` to configure the project.

Deploy:

```powershell
.\scripts\deploy.ps1
```

Execute database migrations:

```powershell
gcloud run jobs execute meridian-migrate --region europe-west1 --wait
```

Clean up after the review:

```powershell
.\scripts\destroy.ps1
```

## Health Verification

The public `/health` endpoint returns the candidate name, deployed Git commit, region, and real-time PostgreSQL and Secret Manager connectivity checks.

Successful checks return `ok`; failures return `error` with HTTP 503.

## Production Improvements

For production, I would add Cloud SQL high availability, automated backups, monitoring, disaster recovery, stronger secrets management, and CI/CD using Workload Identity Federation.

**Time spent:** 3  hours

**Deployment status:** deployed