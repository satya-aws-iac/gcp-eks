# Helper: get GKE credentials using Terraform outputs (PowerShell)
# Run this from the `terraform` directory after `terraform apply` or when state exists.

try {
  $tf = terraform output -json | ConvertFrom-Json
} catch {
  Write-Error "Failed to read Terraform outputs. Run this from the terraform folder and ensure state exists."
  exit 1
}

$cluster = $tf.cluster_name.value
$zone    = $tf.zone.value
$region  = $tf.region.value
$project = $tf.project_id.value

if ([string]::IsNullOrEmpty($cluster)) {
  Write-Error "cluster_name output is empty. Ensure the cluster exists and Terraform state is available."
  exit 1
}

function Get-DefaultZoneFromVariablesTf {
    $varsFile = Join-Path (Get-Location) 'variables.tf'
    if (-not (Test-Path $varsFile)) { return $null }
    $content = Get-Content $varsFile -Raw
    $m = [Regex]::Match($content, 'variable\s+"zone"\s*\{[^}]*default\s*=\s*"(?<zone>[^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) { return $m.Groups['zone'].Value }
    return $null
}

# If zone is empty, try to get default from variables.tf
if ([string]::IsNullOrEmpty($zone)) {
    $fallbackZone = Get-DefaultZoneFromVariablesTf
    if (-not [string]::IsNullOrEmpty($fallbackZone)) {
        $zone = $fallbackZone
        Write-Output "Using zone from variables.tf default: $zone"
    }
}

# Prompt user if still missing
if ([string]::IsNullOrEmpty($zone) -and [string]::IsNullOrEmpty($region)) {
    $input = Read-Host -Prompt 'Zone or region not found in Terraform outputs. Enter zone (e.g. us-central1-a) or press Enter to use region'
    if (-not [string]::IsNullOrEmpty($input)) { $zone = $input }
}

if (-not [string]::IsNullOrEmpty($zone)) {
  Write-Output "Running: gcloud container clusters get-credentials $cluster --zone $zone --project $project"
  gcloud container clusters get-credentials $cluster --zone $zone --project $project
  exit $LASTEXITCODE
}

if (-not [string]::IsNullOrEmpty($region)) {
  Write-Output "Running: gcloud container clusters get-credentials $cluster --region $region --project $project"
  gcloud container clusters get-credentials $cluster --region $region --project $project
  exit $LASTEXITCODE
}

Write-Error "Neither zone nor region is set. Provide a location or ensure Terraform state has the outputs."
exit 1

