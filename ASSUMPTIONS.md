# Assumptions and Architectural Decisions

The following decisions were made without customer confirmation.

1. **EU Region:** Deploy resources in `europe-west1` (Belgium) and store Terraform state in the EU. Use synthetic data only. Review GDPR, data residency, and US expansion requirements before production.

2. **Networking:** Use a dedicated custom VPC (`meridian-vpc`) instead of the default VPC. Cloud Run connects privately to Cloud SQL using Direct VPC egress and Private Services Access. No public database IP.

3. **Database Migrations:** Developers trigger a private Cloud Run Job from their laptops using Google IAM. The job performs migrations inside GCP without exposing PostgreSQL publicly.

4. **CI/CD Authentication:** Reject long-lived JSON service account keys. Use local Application Default Credentials (ADC) for deployment and recommend GitHub Actions OIDC/Workload Identity Federation for CI/CD.

5. **PoC Environment:** Use a small Cloud SQL instance (`db-f1-micro`) and Cloud Run with scale-to-zero. Disable HA, backups, and deletion protection for this temporary demo only. Production requires HA, backups, monitoring, and security controls.

6. **Secrets and Health Checks:** Store two synthetic secrets in Secret Manager. The API reads secrets and executes a real PostgreSQL `SELECT 1` on every `/health` request. Failures return HTTP 503. Demo secrets may appear in Terraform state, so real credentials must use a safer provisioning method.

7. **Deployment:** Use Terraform with remote state in a versioned GCS bucket. Build Docker images tagged with the Git commit SHA. Keep the public endpoint limited to `/health` and grant reviewers read-only project access.

## Additional Implementation Decisions

- **Application:** Python Flask with Cloud SQL Python Connector (`pg8000`, private IP).
- **Security:** Dedicated Cloud Run service account with limited IAM permissions.
- **Credentials:** No real customer data, passwords, or service account keys committed to Git.
- **Cleanup:** Remove demo infrastructure after the review, while retaining the Terraform state bucket until it is separately cleaned up.