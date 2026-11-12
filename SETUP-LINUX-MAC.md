# Linux/macOS setup — Bash

Read [SETUP-WINDOWS.md](SETUP-WINDOWS.md) for the **same** security, cost, Git history, reviewer and cleanup notes. Commands here assume Bash and a running Docker engine.

```bash
# Run once; use your real project and exactly the name given to the recruiter.
gcloud auth login
gcloud auth application-default login
export TF_VAR_project_id='REPLACE_WITH_YOUR_PROJECT_ID'
export TF_VAR_region='europe-west1'
export TF_VAR_candidate_name='REPLACE_WITH_YOUR_EXACT_FULL_NAME'

# Inspect original clarification-only commit and review the files:
git log --oneline --reverse
git config user.name "YOUR NAME"
git config user.email "YOUR_GITHUB_EMAIL"
# After reviewing the files and logging your real AI sessions:
git add .
git commit -m 'docs: reviewed candidate changes and transcripts' || true

# Bootstrap -> platform -> Docker push -> Cloud Run service and migration job.
bash scripts/deploy.sh

# Job is triggered from your laptop but runs with private GCP networking:
gcloud run jobs execute meridian-migrate --region "$TF_VAR_region" --wait

# Test actual endpoint:
terraform -chdir=infra/application output -raw health_url
curl -fsS "$(terraform -chdir=infra/application output -raw health_url)"
```

To grant reviewer IAM via Terraform, after verifying recipient and using an isolated demo project:

```bash
export TF_VAR_reviewer_email='gcp-hr@comm-it.cloud'
SHA="$(terraform -chdir=infra/application output -raw deployed_commit)"
terraform -chdir=infra/application apply "-var=commit_sha=$SHA"
```

After review:

```bash
bash scripts/destroy.sh
# GCS state bucket is intentionally retained: see Windows setup cleanup notes.
```

For a non-interactive shell, confirm Application Default Credentials are configured; never store Google service-account keys in GitHub or your repository.
