Hello,

Before starting the Google Cloud PoC, I'd like to clarify a few architectural and security decisions:

1. **Data Residency:** Must all customer data, backups, and logs remain within the EU? I suggest `europe-west1` for the initial deployment, with US expansion reviewed separately.

2. **Networking:** I recommend a dedicated VPC instead of the default VPC, with private connectivity to Cloud SQL for better isolation and security. Is that acceptable?

3. **Database Migrations:** Do developers need direct database access, or only the ability to trigger migrations? I recommend Cloud Run Jobs with private database access.

4. **CI/CD Security:** Instead of storing long-lived service account JSON keys in GitHub, I recommend Workload Identity Federation (OIDC). Can we use this approach?

5. **PoC vs. Production:** What are the required availability, backup, and compliance standards? For this short PoC, I suggest a low-cost setup and documenting production improvements.

6. **Secrets and API:** Can we use a minimal demo API and synthetic secrets stored in Secret Manager, with real database and secret checks through `/health`?

7. **Deployment:** Who should approve infrastructure changes and execute migrations? I recommend Terraform remote state in GCS and Git SHA-based Docker image tags.

Please confirm these points so we can align the implementation with your requirements.

Regards,  
Google Cloud Delivery Architect