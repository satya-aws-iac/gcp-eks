# GitHub Actions OIDC Configuration for GCP
# This script sets up Workload Identity Federation to use OpenID Connect instead of service account keys

# ============================================
# Set variables - UPDATE THESE VALUES
# ============================================
$PROJECT_ID = "satya-k8-poc"
$PROJECT_NUMBER = "YOUR_PROJECT_NUMBER"  # Find this in GCP Console: gcloud projects describe satya-k8-poc --format='value(projectNumber)'
$GITHUB_ORG = "satya-aws-iac"  # Your GitHub organization or username
$GITHUB_REPO = "gcp-eks"  # Your repository name

# ============================================
# Step 1: Enable required APIs
# ============================================
Write-Host "Step 1: Enabling required APIs..." -ForegroundColor Green

gcloud services enable iamcredentials.googleapis.com `
    --project=$PROJECT_ID

gcloud services enable sts.googleapis.com `
    --project=$PROJECT_ID

gcloud services enable cloudresourcemanager.googleapis.com `
    --project=$PROJECT_ID

Write-Host "✅ APIs enabled successfully" -ForegroundColor Green

# ============================================
# Step 2: Create Workload Identity Pool
# ============================================
Write-Host "Step 2: Creating Workload Identity Pool..." -ForegroundColor Green

gcloud iam workload-identity-pools create "github-pool" `
    --project=$PROJECT_ID `
    --location="global" `
    --display-name="GitHub Actions Pool"

Write-Host "✅ Workload Identity Pool created" -ForegroundColor Green

# ============================================
# Step 3: Create Workload Identity Provider
# ============================================
Write-Host "Step 3: Creating Workload Identity Provider..." -ForegroundColor Green

gcloud iam workload-identity-pools providers create-oidc "github-provider" `
    --project=$PROJECT_ID `
    --location="global" `
    --workload-identity-pool="github-pool" `
    --display-name="GitHub Provider" `
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" `
    --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'" `
    --issuer-uri="https://token.actions.githubusercontent.com"

Write-Host "✅ Workload Identity Provider created" -ForegroundColor Green

# ============================================
# Step 4: Get the Workload Identity Provider resource name
# ============================================
Write-Host "Step 4: Getting Workload Identity Provider resource name..." -ForegroundColor Green

$WORKLOAD_IDENTITY_PROVIDER = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"

Write-Host "Workload Identity Provider: $WORKLOAD_IDENTITY_PROVIDER" -ForegroundColor Yellow

# ============================================
# Step 5: Get the Workload Identity Pool Resource
# ============================================
Write-Host "Step 5: Getting Workload Identity Pool resource name..." -ForegroundColor Green

$WORKLOAD_IDENTITY_POOL_RESOURCE = gcloud iam workload-identity-pools describe github-pool `
    --project=$PROJECT_ID `
    --location="global" `
    --format='value(name)'

Write-Host "Workload Identity Pool Resource: $WORKLOAD_IDENTITY_POOL_RESOURCE" -ForegroundColor Yellow

# ============================================
# Step 6: Create Service Account (if not exists)
# ============================================
Write-Host "Step 6: Ensuring GitHub Actions service account exists..." -ForegroundColor Green

$SERVICE_ACCOUNT = "github-actions-gke@${PROJECT_ID}.iam.gserviceaccount.com"

# Try to create, ignore if already exists
gcloud iam service-accounts create github-actions-gke `
    --display-name="GitHub Actions GKE Service Account" `
    --project=$PROJECT_ID 2>$null

Write-Host "Service Account: $SERVICE_ACCOUNT" -ForegroundColor Yellow

# ============================================
# Step 7: Grant roles to service account
# ============================================
Write-Host "Step 7: Granting IAM roles to service account..." -ForegroundColor Green

$ROLES = @(
    "roles/container.admin",
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectAdmin"
)

foreach ($ROLE in $ROLES) {
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="serviceAccount:$SERVICE_ACCOUNT" `
        --role="$ROLE" 2>$null
    Write-Host "✅ Granted $ROLE" -ForegroundColor Green
}

# ============================================
# Step 8: Create Workload Identity Binding
# ============================================
Write-Host "Step 8: Creating Workload Identity binding..." -ForegroundColor Green

# Allow GitHub Actions to impersonate the service account
$WORKLOAD_IDENTITY_PRINCIPAL = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_ORG/$GITHUB_REPO"

gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT `
    --project=$PROJECT_ID `
    --role="roles/iam.workloadIdentityUser" `
    --member="$WORKLOAD_IDENTITY_PRINCIPAL" 2>$null

Write-Host "✅ Service account configured for Workload Identity" -ForegroundColor Green

# ============================================
# Step 9: Output Configuration for GitHub Actions
# ============================================
Write-Host "`n" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Configuration Ready!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`nAdd the following to your GitHub repository secrets:" -ForegroundColor Yellow
Write-Host "  Name: GCP_PROJECT_ID" -ForegroundColor White
Write-Host "  Value: $PROJECT_ID" -ForegroundColor White

Write-Host "`nAdd the following to your GitHub repository secrets:" -ForegroundColor Yellow
Write-Host "  Name: GCP_WORKLOAD_IDENTITY_PROVIDER" -ForegroundColor White
Write-Host "  Value: ${WORKLOAD_IDENTITY_POOL_RESOURCE}/providers/github-provider" -ForegroundColor White

Write-Host "`nAdd the following to your GitHub repository secrets:" -ForegroundColor Yellow
Write-Host "  Name: GCP_SERVICE_ACCOUNT" -ForegroundColor White
Write-Host "  Value: $SERVICE_ACCOUNT" -ForegroundColor White

Write-Host "`nUpdate your GitHub Actions workflow with:" -ForegroundColor Yellow
Write-Host @"
  - name: Authenticate to Google Cloud
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: `${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      service_account: `${{ secrets.GCP_SERVICE_ACCOUNT }}
      token_format: 'access_token'
"@ -ForegroundColor White

Write-Host "`nRemove the old GCP_SA_KEY secret from GitHub repository settings!" -ForegroundColor Red
Write-Host "`n=====================================" -ForegroundColor Cyan
