# Run AFTER the review. Destroys billable application and platform resources;
# retains the GCS state bucket and its history by design.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $env:TF_VAR_project_id) { throw 'Set TF_VAR_project_id first.' }
if (-not $env:TF_VAR_region) { $env:TF_VAR_region = 'europe-west1' }
Push-Location (Join-Path $PSScriptRoot '..')
try {
  $bucket = (terraform -chdir=infra/bootstrap output -raw state_bucket).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot find bootstrap state.' }
  $env:TF_VAR_state_bucket = $bucket
  # Terraform destroy still parses required variables.
  if (-not $env:TF_VAR_candidate_name) { $env:TF_VAR_candidate_name = 'cleanup' }
  $sha = (terraform -chdir=infra/application output -raw deployed_commit).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot find deployment state.' }
  terraform -chdir=infra/application destroy -auto-approve -var="commit_sha=$sha"
  if ($LASTEXITCODE -ne 0) { throw 'Application destroy failed.' }
  terraform -chdir=infra/platform destroy -auto-approve
  if ($LASTEXITCODE -ne 0) { throw 'Platform destroy failed.' }
  Write-Host "Billable workload destroyed. Retained GCS state bucket: $bucket"
} finally { Pop-Location }
