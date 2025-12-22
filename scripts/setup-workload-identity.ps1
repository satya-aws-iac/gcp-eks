<#
Workload Identity setup script for GitHub Actions (PowerShell)
Edit variables below if you want different names.
Run in Cloud Shell or a machine with `gcloud` configured.
#>

Set-StrictMode -Version Latest

$ProjectId = 'satya-k8-poc'
$PoolId = 'github-pool'
$ProviderId = 'github-provider'
$SaName = 'github-actions'
$GitHubRepo = 'satya-aws-iac/gcp-eks'

Write-Host "Project: $ProjectId" -ForegroundColor Cyan

$ProjectNumber = (& gcloud projects describe $ProjectId --format="value(projectNumber)").Trim()
$SaEmail = "${SaName}@${ProjectId}.iam.gserviceaccount.com"

Write-Host 'Enabling required APIs...' -ForegroundColor Cyan
& gcloud services enable iam.googleapis.com container.googleapis.com artifactregistry.googleapis.com cloudresourcemanager.googleapis.com --project=$ProjectId

Write-Host "Creating workload identity pool: $PoolId" -ForegroundColor Cyan
& gcloud iam workload-identity-pools create $PoolId --project=$ProjectId --location=global --display-name='GitHub Actions Pool'

Write-Host "Creating OIDC provider: $ProviderId" -ForegroundColor Cyan
& gcloud iam workload-identity-pools providers create-oidc $ProviderId --project=$ProjectId --location=global --workload-identity-pool=$PoolId --display-name='GitHub Actions Provider' --issuer-uri='https://token.actions.githubusercontent.com' --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor'

Write-Host "Creating service account: $SaName" -ForegroundColor Cyan
& gcloud iam service-accounts create $SaName --project=$ProjectId --display-name='GitHub Actions Service Account'

Write-Host "Granting IAM roles to service account: $SaEmail" -ForegroundColor Cyan
& gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$SaEmail" --role="roles/artifactregistry.writer"
& gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$SaEmail" --role="roles/container.developer"
& gcloud projects add-iam-policy-binding $ProjectId --member="serviceAccount:$SaEmail" --role="roles/iam.serviceAccountUser"

Write-Host "Allowing workload identity pool members to impersonate the SA" -ForegroundColor Cyan
& gcloud iam service-accounts add-iam-policy-binding $SaEmail --project=$ProjectId --role='roles/iam.workloadIdentityUser' --member="principalSet://iam.googleapis.com/projects/$ProjectNumber/locations/global/workloadIdentityPools/$PoolId/attribute.repository/$GitHubRepo"

Write-Host ""; Write-Host 'Done.' -ForegroundColor Green
Write-Host "Update your GitHub Actions workflow with these values:" -ForegroundColor Cyan
Write-Host "  workload_identity_provider: projects/$ProjectNumber/locations/global/workloadIdentityPools/$PoolId/providers/$ProviderId" -ForegroundColor Yellow
Write-Host "  service_account: $SaEmail" -ForegroundColor Yellow
Write-Host "Add GitHub Secrets: GKE_CLUSTER and GKE_LOCATION (no JSON key needed)." -ForegroundColor Yellow
