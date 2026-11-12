# Windows setup — follow in PowerShell

**IMPORTANT:** This repository has NOT been deployed for you. It needs **your** Google Cloud account, billing and credentials. Cloud SQL is a billable service. Review the code first, and don't exceed Commit's five-hour work limit.

## 1. Prerequisites (install if missing)

- A **Google Cloud project** you own, with **billing enabled** and permission to enable APIs, create SQL/VPC/IAM, and manage buckets. Creating a project/billing link is an account prerequisite, not Terraform provisioning of project infrastructure.
- Google Cloud CLI (`gcloud`), Terraform >= 1.6, Git, Docker Desktop with Linux containers. Docker Desktop must be running.
- Enough GCP quota for a small Cloud SQL PostgreSQL instance. Trial credits may cover costs but **this is not guaranteed to be free**.
- PowerShell in the unzipped repository root. Verify the included `.git` folder is present. It contains the required **first clarification-only commit**.

## 2. Authenticate (run once)

```powershell
gcloud auth login
gcloud auth application-default login
```

Use your existing project ID (not its display name). Do **not** download service account JSON keys.

## 3. Set project and name in PowerShell

```powershell
$env:TF_VAR_project_id = 'REPLACE_WITH_YOUR_PROJECT_ID'
$env:TF_VAR_region = 'europe-west1'
$env:TF_VAR_candidate_name = 'REPLACE_WITH_YOUR_EXACT_FULL_NAME'
```

For the health contract, the name must match what you told Commit. These settings apply to the **current PowerShell session**. Rerun them when starting a new shell.

## 4. Review and commit **before** deployment

`CLARIFICATIONS.md` was deliberately committed by itself as the first Git commit. **Do not rewrite it** after starting the design, as the assignment requires. Read `ASSUMPTIONS.md`, `infra/`, `app/`, and `README.md` in your own words. Fill any genuine AI log entries you have already generated; do not submit a placeholder.

```powershell
git log --oneline --reverse
git config user.name "YOUR NAME"
git config user.email "YOUR_GITHUB_EMAIL"
git status
git add .
git commit -m 'docs: reviewed deployment instructions and AI transcript'
```

If nothing changed, the commit may simply say there is nothing to commit; that's okay. The deploy script intentionally refuses dirty worktrees to maintain an accurate image SHA.

## 5. Deploy the whole environment

```powershell
.\scripts\deploy.ps1
```

The script will:

1. Provision a versioned state bucket in GCP with **bootstrap Terraform**, then migrate the bootstrap state into that bucket.
2. Run **platform Terraform** for all APIs, VPC, private services access, PostgreSQL, IAM, regional Secret Manager versions, and Artifact Registry.
3. Build a Docker image locally and push it to Artifact Registry, tagged with `git rev-parse --short=7 HEAD`.
4. Run **application Terraform** for the public Cloud Run service, private migration job and optional viewer permissions, using remote state.
5. Print the live `/health` URL.

Cloud SQL often takes several minutes to create. If GCP denies access due to organization policies, quotas, permissions or billing, **do not** weaken security requirements. Record the blocker and remaining work in README at the five-hour stop.

## 6. Execute a real migration and test

```powershell
gcloud run jobs execute meridian-migrate --region europe-west1 --wait
```

The job runs SQL in `app/migrations/` privately. To allow a colleague to execute it, grant that person **Cloud Run Invoker on the migration job** after approval (prefer Terraform); they do not need a public PostgreSQL endpoint.

Test the URL printed by the deploy script in the browser or PowerShell:

```powershell
$health = (terraform -chdir=infra/application output -raw health_url).Trim()
Invoke-RestMethod -Uri $health
```

Expected shape (values below are illustrative, **not deployment evidence**):

```json
{"candidate":"Your Exact Name","commit":"abcdef1","region":"europe-west1","db":"ok","secret":"ok"}
```

Inspect the real Cloud Run logs if `db` or `secret` report `error`. The endpoint checks both dependencies on **every request**, and responds HTTP 503 on failure.

## 7. Grant review access and publish to GitHub

The assignment requests *project-level Viewer* for `gcp-hr@comm-it.cloud`, plus Git repository access. To create that IAM binding **with Terraform**, after verification:

```powershell
$env:TF_VAR_reviewer_email = 'gcp-hr@comm-it.cloud'
$sha = (terraform -chdir=infra/application output -raw deployed_commit).Trim()
terraform -chdir=infra/application apply -var="commit_sha=$sha"
```

Do this only in the intended **isolated demo project**: GCP read-only access can still permit access to information in state buckets. This demo uses only generated fake tokens; never put real third-party tokens in Terraform state. The address above is taken from the exercise PDF; verify recipient identity with the recruiter before granting access.

Create a GitHub repository and add it as remote (replace placeholder URL):

```powershell
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

If the repo is private, grant the reviewer access. Finish all README and AI-LOG requirements and commit/push **before submission**. Be mindful that a later documentation commit does not change which *earlier code commit* is deployed, until you rebuild/redeploy.

## 8. After the review: destroy billable resources

```powershell
.\scripts\destroy.ps1
```

This destroys Cloud Run/Job, Cloud SQL, secrets, registry and VPC managed by platform/application states. **It intentionally retains the GCS Terraform-state bucket and prior versions** for audit; inspect and securely delete state objects/bucket separately *after you no longer need recovery*. Deleting the bucket destroys the remote state history and cannot be undone. Check the GCP Billing page for any remaining charges or resources.
