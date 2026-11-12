# Optional GitHub Actions Terraform-plan design (bonus)

The `.github/workflows/terraform-plan.yml` file illustrates a read-only, PR-scoped Terraform plan. **It will not work until you explicitly configure Google Workload Identity Federation (WIF) and GitHub variables.** The assignment says a clear explanation suffices for the bonus; prioritize a correct running system.

## Architecture

1. Create a GitHub OIDC federation trust in a Google IAM Workload Identity Pool and Provider (via Terraform in a dedicated identity/bootstrap stack) for `https://token.actions.githubusercontent.com`.
2. Bind `attribute.repository == 'YOUR_ORG/YOUR_REPO'` and preferably restrict tokens to approved refs/workflows; avoid accepting tokens from arbitrary repositories.
3. Create a separate CI service account. Grant only the Google resource `get/list` or other precise permissions needed to compute the proposed plan; allow the GCS backend access strictly as needed. Be aware `terraform plan` may require permissions beyond `roles/viewer` to refresh state, and GCS state **contains synthetic DB credentials**.
4. Configure GitHub **repository variables** `GCP_PROJECT_ID`, `GCP_TF_STATE_BUCKET`, `GCP_WORKLOAD_IDENTITY_PROVIDER` (full provider resource), and `GCP_TERRAFORM_SERVICE_ACCOUNT` (email). Do not create a JSON key or secret. Use `id-token: write` to get an ephemeral identity token.
5. GitHub Action `google-github-actions/auth@v2` exchanges the OIDC assertion for short-lived Google credentials, then Terraform initializes GCS remote state and runs `plan -no-color` on the platform stack.
6. Protect `main`; production `apply` should require approval and a separate deploy identity with more privileges. This sample does **not** run `terraform apply` on pull requests.

The optional WIF identity resources are intentionally **not** provisioned without a real repository owner/name and an approval model. Record this as unfinished bonus work, not a working pipeline.
