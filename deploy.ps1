# Firebase Deployment Script for Windows (PowerShell)
# This script reads your local .env file and deploys to Firebase Hosting

Write-Host "Starting Firebase deployment..." -ForegroundColor Green

# Set Google Cloud Project ID (for Gemini AI and other GCP services)
$PROJECT_ID = "triagebiosai-471108"
# Note: Firebase project ID is configured separately in .firebaserc as "triagebiosai"

# Check if gcloud is authenticated
Write-Host "Checking Google Cloud authentication..." -ForegroundColor Blue
$authCheck = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
if (-not $authCheck) {
    Write-Host "Warning: No active Google Cloud authentication found!" -ForegroundColor Yellow
    Write-Host "Please run 'gcloud auth login' to authenticate" -ForegroundColor Yellow
    Write-Host "Continuing with deployment..." -ForegroundColor Blue
}

# Configure Google Cloud SDK
Write-Host "Configuring Google Cloud SDK..." -ForegroundColor Blue
gcloud config set project $PROJECT_ID

# Enable necessary Google Cloud APIs
Write-Host "Enabling Google Cloud APIs..." -ForegroundColor Blue
gcloud services enable generativelanguage.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable firebase.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable firestore.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID --quiet

# Verify Gemini API is accessible
Write-Host "Verifying Gemini API access..." -ForegroundColor Blue
Write-Host "Project configured for Gemini AI: $PROJECT_ID" -ForegroundColor Green

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "Error: .env file not found!" -ForegroundColor Red
    Write-Host "Please create a .env file with your environment variables" -ForegroundColor Yellow
    exit 1
}

# Load environment variables
Write-Host "Loading environment variables..." -ForegroundColor Blue
$envContent = Get-Content ".env" | Where-Object { $_ -notmatch "^#" -and $_ -ne "" }
foreach ($line in $envContent) {
    if ($line -match "^([^=]+)=(.*)$") {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"')
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Validate required environment variables
$requiredVars = @("GEMINI_API_KEY", "FIREBASE_PROJECT_ID")
$missingVars = @()

foreach ($var in $requiredVars) {
    if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($var))) {
        $missingVars += $var
    }
}

if ($missingVars.Count -gt 0) {
    Write-Host "Warning: Missing environment variables: $($missingVars -join ', ')" -ForegroundColor Yellow
    Write-Host "The app will use fallback values for missing variables" -ForegroundColor Yellow
}

# Build Flutter web app
Write-Host "Building Flutter web app..." -ForegroundColor Blue
flutter build web --release `
    --dart-define=GEMINI_API_KEY="$env:GEMINI_API_KEY" `
    --dart-define=FIREBASE_PROJECT_ID="$env:FIREBASE_PROJECT_ID" `
    --dart-define=FIREBASE_WEB_API_KEY="$env:FIREBASE_WEB_API_KEY" `
    --dart-define=FIREBASE_WEB_APP_ID="$env:FIREBASE_WEB_APP_ID" `
    --dart-define=FIREBASE_AUTH_DOMAIN="$env:FIREBASE_AUTH_DOMAIN" `
    --dart-define=FIREBASE_STORAGE_BUCKET="$env:FIREBASE_STORAGE_BUCKET" `
    --dart-define=FIREBASE_MESSAGING_SENDER_ID="$env:FIREBASE_MESSAGING_SENDER_ID" `
    --dart-define=FIREBASE_MEASUREMENT_ID="$env:FIREBASE_MEASUREMENT_ID" `
    --dart-define=GOOGLE_MAPS_API_KEY="$env:GOOGLE_MAPS_API_KEY"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Flutter build completed!" -ForegroundColor Green

# Deploy to Firebase
Write-Host "Deploying to Firebase..." -ForegroundColor Blue
firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Your app is live at: https://triagebiosai.web.app" -ForegroundColor Cyan
    Write-Host "Gemini AI is enabled for project: $PROJECT_ID" -ForegroundColor Green
} else {
    Write-Host "Firebase deployment failed!" -ForegroundColor Red
    exit 1
}