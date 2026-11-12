# START HERE — Commit Google Cloud Architect exercise

**This ZIP is a generated starter implementation, not a submitted or deployed solution.** Review and understand it before using it as your own interview work.

1. **Unzip the folder completely**, including the hidden `.git` directory. Open it in VS Code or a terminal. `git log --oneline --reverse` must show the clarification-only first commit.
2. Read `CLARIFICATIONS.md` (do not rewrite), then `ASSUMPTIONS.md` and `README.md`. Open `SETUP-WINDOWS.md` if using PowerShell/Windows; otherwise read `SETUP-LINUX-MAC.md`.
3. Ensure you have an existing GCP project, billing enabled, plus Terraform, Git, Docker, and `gcloud`. Authenticate locally with `gcloud auth login` and `gcloud auth application-default login`.
4. Set `TF_VAR_project_id`, `TF_VAR_region`, and `TF_VAR_candidate_name` exactly as shown in the OS setup guide. Review all code. Make genuine updates, **log every AI exchange in `AI-LOG.md`**, then commit your changes to make the deploy Git SHA meaningful.
5. Run `scripts/deploy.ps1` (PowerShell) or `bash scripts/deploy.sh` (Bash), test the real `/health`, and execute the private migration job. **No GCP resources have been created for you.**

**Before submitting:** verify the reviewer email, give project Viewer IAM using Terraform, publish the repository, fill the README with actual time and AI usage, and replace the AI-LOG placeholder with complete conversations. Include three *real* corrections/rejections of AI proposals. Keep the environment live through review; run `scripts/destroy.*` afterwards. The state bucket remains by design.

**Cost and safety:** Cloud SQL is billable. Do not use real payment data or third-party tokens in this demo. Terraform state contains generated synthetic credentials. If deployment or testing fails, record the exact error and the unfinished work rather than claiming success.
