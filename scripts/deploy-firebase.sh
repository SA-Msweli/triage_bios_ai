#!/bin/bash

# Firebase Deployment Script for Triage-BIOS.ai
# This script handles deployment to different environments (dev, staging, prod)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
SKIP_TESTS=false
SKIP_BUILD=false
DRY_RUN=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Target environment (dev|staging|prod) [default: dev]"
    echo "  -s, --skip-tests        Skip running tests before deployment"
    echo "  -b, --skip-build        Skip building the application"
    echo "  -d, --dry-run           Show what would be deployed without actually deploying"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e staging           Deploy to staging environment"
    echo "  $0 -e prod -s           Deploy to production, skipping tests"
    echo "  $0 -d                   Dry run for development environment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -b|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
fi

print_status "Starting deployment to $ENVIRONMENT environment..."

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        print_error "Firebase CLI is not installed. Please install it first:"
        print_error "npm install -g firebase-tools"
        exit 1
    fi
    
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed. Please install Flutter first."
        exit 1
    fi
    
    # Check if logged into Firebase
    if ! firebase projects:list &> /dev/null; then
        print_error "Not logged into Firebase. Please run: firebase login"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Set environment configuration
set_environment() {
    print_status "Setting up environment configuration for $ENVIRONMENT..."
    
    case $ENVIRONMENT in
        dev)
            export FIREBASE_PROJECT="triage-bios-dev"
            export FLUTTER_ENV="development"
            ;;
        staging)
            export FIREBASE_PROJECT="triage-bios-staging"
            export FLUTTER_ENV="staging"
            ;;
        prod)
            export FIREBASE_PROJECT="triage-bios-prod"
            export FLUTTER_ENV="production"
            ;;
    esac
    
    # Set Firebase project
    firebase use $FIREBASE_PROJECT
    
    print_success "Environment set to $ENVIRONMENT (project: $FIREBASE_PROJECT)"
}

# Run tests
run_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        print_warning "Skipping tests as requested"
        return
    fi
    
    print_status "Running tests..."
    
    # Run Flutter tests
    flutter test
    
    # Run Firebase Functions tests (if they exist)
    if [ -d "functions" ] && [ -f "functions/package.json" ]; then
        cd functions
        npm test
        cd ..
    fi
    
    print_success "All tests passed"
}

# Build application
build_application() {
    if [ "$SKIP_BUILD" = true ]; then
        print_warning "Skipping build as requested"
        return
    fi
    
    print_status "Building application for $ENVIRONMENT..."
    
    # Clean previous builds
    flutter clean
    flutter pub get
    
    # Build for web
    flutter build web --dart-define=ENVIRONMENT=$FLUTTER_ENV
    
    print_success "Application built successfully"
}

# Deploy Firestore rules and indexes
deploy_firestore() {
    print_status "Deploying Firestore rules and indexes..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would deploy Firestore rules and indexes"
        return
    fi
    
    firebase deploy --only firestore:rules,firestore:indexes
    
    print_success "Firestore rules and indexes deployed"
}

# Deploy Firebase Functions
deploy_functions() {
    if [ ! -d "functions" ]; then
        print_warning "No functions directory found, skipping functions deployment"
        return
    fi
    
    print_status "Deploying Firebase Functions..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would deploy Firebase Functions"
        return
    fi
    
    # Install dependencies
    cd functions
    npm ci
    cd ..
    
    firebase deploy --only functions
    
    print_success "Firebase Functions deployed"
}

# Deploy web hosting
deploy_hosting() {
    print_status "Deploying web application..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would deploy web application"
        return
    fi
    
    firebase deploy --only hosting
    
    print_success "Web application deployed"
}

# Seed initial data (dev environment only)
seed_data() {
    if [ "$ENVIRONMENT" != "dev" ]; then
        return
    fi
    
    print_status "Seeding development data..."
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would seed development data"
        return
    fi
    
    # Run data seeding script
    if [ -f "scripts/seed-data.js" ]; then
        node scripts/seed-data.js
        print_success "Development data seeded"
    else
        print_warning "No data seeding script found"
    fi
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Get the hosting URL
    HOSTING_URL=$(firebase hosting:channel:list | grep -E "live|$ENVIRONMENT" | awk '{print $4}' | head -1)
    
    if [ -z "$HOSTING_URL" ]; then
        print_warning "Could not determine hosting URL"
        return
    fi
    
    print_status "Testing deployment at: $HOSTING_URL"
    
    # Basic health check
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HOSTING_URL" || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ]; then
        print_success "Deployment verification passed"
        print_success "Application is live at: $HOSTING_URL"
    else
        print_error "Deployment verification failed (HTTP $HTTP_STATUS)"
        exit 1
    fi
}

# Main deployment flow
main() {
    print_status "=== Firebase Deployment Script ==="
    print_status "Environment: $ENVIRONMENT"
    print_status "Skip Tests: $SKIP_TESTS"
    print_status "Skip Build: $SKIP_BUILD"
    print_status "Dry Run: $DRY_RUN"
    print_status "=================================="
    
    check_prerequisites
    set_environment
    run_tests
    build_application
    deploy_firestore
    deploy_functions
    deploy_hosting
    seed_data
    verify_deployment
    
    print_success "=== Deployment Complete ==="
    print_success "Environment: $ENVIRONMENT"
    print_success "Timestamp: $(date)"
    print_success "=========================="
}

# Run main function
main