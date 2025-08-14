# Firebase Deployment Script for Windows (PowerShell)
# This script reads your local .env file and deploys to Firebase Hosting

Write-Host "Starting Firebase deployment..." -ForegroundColor Green

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
$requiredVars = @("WATSONX_API_KEY", "WATSONX_PROJECT_ID", "FIREBASE_PROJECT_ID")
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
    --dart-define=WATSONX_API_KEY="$env:WATSONX_API_KEY" `
    --dart-define=WATSONX_PROJECT_ID="$env:WATSONX_PROJECT_ID" `
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
} else {
    Write-Host "Firebase deployment failed!" -ForegroundColor Red
    exit 1
}