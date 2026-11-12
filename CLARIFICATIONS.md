**To:** Meridian Payments — Platform Lead  
**Subject:** Google Cloud evaluation: decisions to confirm before implementation

Hello,

Before we start building the three-week evaluation, I'd like to confirm a few points so the prototype reflects a defensible production pattern rather than only a working demonstration.

1. **EU residency and future US users.** Must payment, customer and operational data remain inside the EEA, including backups, secrets and logs? Is there a mandated region or availability objective? US expansion need not imply a US-hosted database, so I suggest keeping this initial environment in one EU region until data-residency and latency requirements are agreed.
2. **Network isolation.** I recommend *not* using the default VPC. Cloud SQL private IP does not mean the API and database must share one unrestricted default network. A dedicated VPC with private services access is simpler to audit and isolates this evaluation from unrelated workloads. Can we use that design?
3. **Developer migrations.** Do developers require direct PostgreSQL access from laptops, or the ability to *initiate* a migration from them? I recommend an authenticated Cloud Run Job executed through the Google Cloud API, with private database connectivity. This avoids exposing database ports or distributing network access and database passwords to individual devices. Is that acceptable?
4. **GitHub credentials.** I cannot recommend a long-lived service-account JSON key in GitHub Secrets. It creates a persistent credential that can be leaked or forgotten. Can we use GitHub OIDC with Google Workload Identity Federation and narrowly scoped permissions for CI instead?
5. **Proof-of-concept versus production.** What uptime, disaster recovery, RPO/RTO, monitoring, retention, and payment-compliance controls are non-negotiable for this evaluation? For a three-week demo, I propose a low-cost single-zone database, while explicitly documenting the changes required before handling real payments or regulated data.
6. **API and secrets.** Is a deliberately minimal demo endpoint acceptable, with a nonfunctional sample third-party token? I propose storing the demo token and DB password in Secret Manager, retrieving them with the application's own identity, and verifying DB access and Secret Manager access on every `/health` request.
7. **Delivery workflow.** Is the existing GitHub repository available, and which engineering team should be allowed to trigger migrations and approve infrastructure changes? I propose immutable image tags using Git commit SHAs and Terraform remote state in a versioned GCS bucket.

Given the evaluation timeline, I'll document provisional decisions and the rationale for each if we cannot clarify these items before work starts. Please let me know which assumptions are unacceptable, particularly the compliance and developer-access requirements.

Regards,  
Google Cloud Delivery Architect
