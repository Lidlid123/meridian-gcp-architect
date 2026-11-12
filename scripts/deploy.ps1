# Run from the repository root: .\scripts\deploy.ps1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function RunChecked([string]$cmd, [string[]]$params) {
    & $cmd @params
    if ($LASTEXITCODE -ne 0) { throw "$cmd failed (exit $LASTEXITCODE): $($params -join ' ')" }
}

foreach ($command in @('terraform', 'gcloud', 'git', 'docker')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "Missing $command. See SETUP-WINDOWS.md" }
}
if (-not $env:TF_VAR_project_id) { throw 'Set $env:TF_VAR_project_id first.' }
if (-not $env:TF_VAR_candidate_name) { throw 'Set $env:TF_VAR_candidate_name to your exact recruiter name first.' }
if (-not $env:TF_VAR_region) { $env:TF_VAR_region = 'europe-west1' }

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repo
try {
    $dirty = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw 'Commit all changes before deploying. The image tag must equal the Git commit SHA.' }
    $sha = (git rev-parse --short=7 HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Git SHA unavailable.' }
    $project = $env:TF_VAR_project_id
    $region = $env:TF_VAR_region

    RunChecked 'gcloud' @('config', 'set', 'project', $project)
    # First bootstrap creates the bucket from local state, then migrates its own state.
    $bootBackend = Join-Path $repo 'infra/bootstrap/backend.tf'
    if (-not (Test-Path $bootBackend)) {
        RunChecked 'terraform' @('-chdir=infra/bootstrap', 'init', '-input=false')
        RunChecked 'terraform' @('-chdir=infra/bootstrap', 'apply', '-input=false', '-auto-approve')
        $bucket = (terraform -chdir=infra/bootstrap output -raw state_bucket).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $bucket) { throw 'Cannot read the state bucket output.' }
        @"
terraform {
  backend "gcs" {
    bucket = "$bucket"
    prefix = "meridian/bootstrap"
  }
}
"@ | Set-Content -Encoding utf8 $bootBackend
        RunChecked 'terraform' @('-chdir=infra/bootstrap', 'init', '-migrate-state', '-force-copy', '-input=false')
    } else {
        RunChecked 'terraform' @('-chdir=infra/bootstrap', 'init', '-input=false')
        $bucket = (terraform -chdir=infra/bootstrap output -raw state_bucket).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $bucket) { throw 'Cannot read the state bucket output.' }
    }

    $env:TF_VAR_state_bucket = $bucket
    RunChecked 'terraform' @('-chdir=infra/platform', 'init', '-input=false', '-reconfigure', "-backend-config=bucket=$bucket")
    RunChecked 'terraform' @('-chdir=infra/platform', 'apply', '-input=false', '-auto-approve')

    $image = "$region-docker.pkg.dev/$project/meridian-api/api:$sha"
    RunChecked 'gcloud' @('auth', 'configure-docker', "$region-docker.pkg.dev", '--quiet')
    RunChecked 'docker' @('build', '-t', $image, 'app')
    RunChecked 'docker' @('push', $image)

    RunChecked 'terraform' @('-chdir=infra/application', 'init', '-input=false', '-reconfigure', "-backend-config=bucket=$bucket")
    RunChecked 'terraform' @('-chdir=infra/application', 'apply', '-input=false', '-auto-approve', "-var=commit_sha=$sha")

    Write-Host "`nSUCCESS — deployed Git commit $sha" -ForegroundColor Green
    Write-Host 'Health URL:'
    RunChecked 'terraform' @('-chdir=infra/application', 'output', '-raw', 'health_url')
    Write-Host "`nFirst run (private migration job): gcloud run jobs execute meridian-migrate --region $region --wait"
} finally {
    Pop-Location
}
