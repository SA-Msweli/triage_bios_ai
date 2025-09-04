#!/bin/bash

# Firebase Deployment Script for Linux/macOS
# This script reads your local .env file and deploys to Firebase Hosting

echo "Starting Firebase deployment..."

# Set Google Cloud Project ID (for Gemini AI and other GCP services)
PROJECT_ID="triagebiosai-471108"
# Note: Firebase project ID is configured separately in .firebaserc as "triagebiosai"

# Check if gcloud is authenticated
echo "Checking Google Cloud authentication..."
AUTH_CHECK=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$AUTH_CHECK" ]; then
    echo "Warning: No active Google Cloud authentication found!"
    echo "Please run 'gcloud auth login' to authenticate"
    echo "Continuing with deployment..."
fi

# Configure Google Cloud SDK
echo "Configuring Google Cloud SDK..."
gcloud config set project $PROJECT_ID

# Enable necessary Google Cloud APIs
echo "Enabling Google Cloud APIs..."
gcloud services enable generativelanguage.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable firebase.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable firestore.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID --quiet

# Verify Gemini API is accessible
echo "Verifying Gemini API access..."
echo "Project configured for Gemini AI: $PROJECT_ID"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    echo "Please create a .env file with your environment variables"
    exit 1
fi

# Load environment variables from .env file
echo "Loading environment variables..."
export $(grep -v '^#' .env | xargs)

# Validate required environment variables
required_vars=("GEMINI_API_KEY" "FIREBASE_PROJECT_ID")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Warning: Missing environment variables: ${missing_vars[*]}"
    echo "The app will use fallback values for missing variables"
fi

# Build Flutter web app
echo "Building Flutter web app..."
flutter build web \
    --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
    --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
    --dart-define=FIREBASE_WEB_API_KEY="$FIREBASE_WEB_API_KEY" \
    --dart-define=FIREBASE_WEB_APP_ID="$FIREBASE_WEB_APP_ID" \
    --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
    --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
    --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID" \
    --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY" \
    --release

if [ $? -ne 0 ]; then
    echo "Flutter build failed!"
    exit 1
fi

echo "Flutter build completed!"

# Deploy to Firebase Hosting
echo "Deploying to Firebase..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
    echo "Deployment completed successfully!"
    echo "Your app is live at: https://triagebiosai.web.app"
    echo "Gemini AI is enabled for project: $PROJECT_ID"
else
    echo "Firebase deployment failed!"
    exit 1
fi