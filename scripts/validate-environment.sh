#!/bin/bash

# Environment Validation Script for Triage-BIOS.ai
# This script validates that the deployment environment is properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-dev}
ERRORS=0

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((ERRORS++))
}

print_status "Validating environment: $ENVIRONMENT"
echo "=================================="

# Check Firebase CLI
if command -v firebase &> /dev/null; then
    FIREBASE_VERSION=$(firebase --version)
    print_success "Firebase CLI installed: $FIREBASE_VERSION"
else
    print_error "Firebase CLI not installed"
fi

# Check Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    print_success "Flutter installed: $FLUTTER_VERSION"
else
    print_error "Flutter not installed"
fi

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"
else
    print_warning "Node.js not found (required for Firebase Functions)"
fi

# Check Firebase authentication
if firebase projects:list &> /dev/null; then
    print_success "Firebase authentication valid"
else
    print_error "Firebase authentication failed - run 'firebase login'"
fi

# Check environment file
ENV_FILE=".env.$ENVIRONMENT"
if [ -f "$ENV_FILE" ]; then
    print_success "Environment file found: $ENV_FILE"
    
    # Check required variables
    REQUIRED_VARS=("FIREBASE_PROJECT_ID" "FIREBASE_API_KEY")
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^$var=" "$ENV_FILE"; then
            print_success "Required variable found: $var"
        else
            print_error "Missing required variable: $var in $ENV_FILE"
        fi
    done
else
    print_error "Environment file not found: $ENV_FILE"
    print_status "Copy from template: cp config/env.$ENVIRONMENT.template $ENV_FILE"
fi

# Check Firebase project configuration
if [ -f "firebase.json" ]; then
    print_success "Firebase configuration found"
else
    print_warning "Firebase configuration not found - run 'firebase init'"
fi

# Check Firestore rules
if [ -f "firestore.rules" ]; then
    print_success "Firestore rules found"
else
    print_warning "Firestore rules not found"
fi

# Check Flutter dependencies
if [ -f "pubspec.yaml" ]; then
    print_success "Flutter project configuration found"
    
    if [ -d ".dart_tool" ]; then
        print_success "Flutter dependencies installed"
    else
        print_warning "Flutter dependencies not installed - run 'flutter pub get'"
    fi
else
    print_error "Flutter project not found (pubspec.yaml missing)"
fi

# Check build directory
if [ -d "build/web" ]; then
    print_success "Web build directory exists"
else
    print_warning "Web build not found - will build during deployment"
fi

echo "=================================="

if [ $ERRORS -eq 0 ]; then
    print_success "Environment validation passed! Ready for deployment."
    exit 0
else
    print_error "Environment validation failed with $ERRORS error(s)."
    print_status "Please fix the errors above before deploying."
    exit 1
fi