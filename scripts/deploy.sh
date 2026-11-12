#!/usr/bin/env bash
# Run from the repository root: bash scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
for command in terraform gcloud git docker; do command -v "$command" >/dev/null || { echo "Missing $command" >&2; exit 1; }; done
: "${TF_VAR_project_id:?Set TF_VAR_project_id to the existing GCP project ID}"
: "${TF_VAR_candidate_name:?Set TF_VAR_candidate_name to the exact name used with the recruiter}"
export TF_VAR_region="${TF_VAR_region:-europe-west1}"
if [[ -n "$(git status --porcelain)" ]]; then echo 'Commit all changes before deployment: the Git SHA must match the image.' >&2; exit 1; fi
SHA="$(git rev-parse --short=7 HEAD)"
PROJECT="$TF_VAR_project_id"
REGION="$TF_VAR_region"
gcloud config set project "$PROJECT"
if [[ ! -f infra/bootstrap/backend.tf ]]; then
  terraform -chdir=infra/bootstrap init -input=false
  terraform -chdir=infra/bootstrap apply -input=false -auto-approve
  BUCKET="$(terraform -chdir=infra/bootstrap output -raw state_bucket)"
  cat > infra/bootstrap/backend.tf <<BACKEND
terraform {
  backend "gcs" {
    bucket = "$BUCKET"
    prefix = "meridian/bootstrap"
  }
}
BACKEND
  terraform -chdir=infra/bootstrap init -migrate-state -force-copy -input=false
else
  terraform -chdir=infra/bootstrap init -input=false
  BUCKET="$(terraform -chdir=infra/bootstrap output -raw state_bucket)"
fi
export TF_VAR_state_bucket="$BUCKET"
terraform -chdir=infra/platform init -reconfigure -input=false "-backend-config=bucket=$BUCKET"
terraform -chdir=infra/platform apply -input=false -auto-approve
IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/meridian-api/api:${SHA}"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
docker build -t "$IMAGE" app
docker push "$IMAGE"
terraform -chdir=infra/application init -reconfigure -input=false "-backend-config=bucket=$BUCKET"
terraform -chdir=infra/application apply -input=false -auto-approve "-var=commit_sha=$SHA"
echo "Deployed commit $SHA. Health URL:"
terraform -chdir=infra/application output -raw health_url
printf '\nTrigger private database migration: gcloud run jobs execute meridian-migrate --region %s --wait\n' "$REGION"
