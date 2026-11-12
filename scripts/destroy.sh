#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TF_VAR_project_id:?Set TF_VAR_project_id first}"
export TF_VAR_region="${TF_VAR_region:-europe-west1}"
export TF_VAR_candidate_name="${TF_VAR_candidate_name:-cleanup}"
export TF_VAR_state_bucket="$(terraform -chdir=infra/bootstrap output -raw state_bucket)"
SHA="$(terraform -chdir=infra/application output -raw deployed_commit)"
terraform -chdir=infra/application destroy -auto-approve "-var=commit_sha=$SHA"
terraform -chdir=infra/platform destroy -auto-approve
echo "Billable workload destroyed. Retained GCS state bucket: $TF_VAR_state_bucket"
