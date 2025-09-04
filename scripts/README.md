# Deployment Scripts

## Overview

This directory contains deployment scripts for the Triage-BIOS.ai Firebase integration. The scripts handle automated deployment to different environments (development, staging, production) with comprehensive validation and rollback capabilities.

## Available Scripts

### 1. `deploy-firebase.sh` (Unix/Linux/macOS)
Bash script for Unix-based systems.

### 2. `deploy-firebase.bat` (Windows)
Batch script for Windows systems.

### 3. `data_migration_cli.dart` (Data Migration)
Dart CLI tool for migrating data between environments.

## Usage

### Basic Deployment

**Unix/Linux/macOS:**
```bash
# Make script executable (first time only)
chmod +x scripts/deploy-firebase.sh

# Deploy to development (default)
./scripts/deploy-firebase.sh

# Deploy to staging
./scripts/deploy-firebase.sh -e staging

# Deploy to production
./scripts/deploy-firebase.sh -e prod
```

**Windows:**
```cmd
# Deploy to development (default)
scripts\deploy-firebase.bat

# Deploy to staging
scripts\deploy-firebase.bat -e staging

# Deploy to production
scripts\deploy-firebase.bat -e prod
```

### Advanced Options

```bash
# Skip tests (faster deployment)
./scripts/deploy-firebase.sh -e staging -s

# Skip build (use existing build)
./scripts/deploy-firebase.sh -e prod -b

# Dry run (show what would be deployed)
./scripts/deploy-firebase.sh -e prod -d

# Skip both tests and build
./scripts/deploy-firebase.sh -e staging -s -b
```

### Help

```bash
# Show usage information
./scripts/deploy-firebase.sh -h
./scripts/deploy-firebase.sh --help
```

## Prerequisites

Before running the deployment scripts, ensure you have:

1. **Firebase CLI installed**
   ```bash
   npm install -g firebase-tools
   ```

2. **Flutter SDK installed**
   - Download from [flutter.dev](https://flutter.dev)
   - Add to PATH

3. **Firebase authentication**
   ```bash
   firebase login
   ```

4. **Project dependencies**
   ```bash
   flutter pub get
   ```

## Environment Configuration

### 1. Copy Environment Templates
```bash
# Development
cp config/env.development.template .env.development

# Staging
cp config/env.staging.template .env.staging

# Production
cp config/env.production.template .env.production
```

### 2. Update Configuration Values
Edit the `.env.*` files with your actual Firebase project details:

```bash
FIREBASE_PROJECT_ID=your-actual-project-id
FIREBASE_API_KEY=your-actual-api-key
# ... other values
```

## Deployment Process

The deployment scripts follow this process:

1. **Prerequisites Check**
   - Verify Firebase CLI installation
   - Verify Flutter installation
   - Check Firebase authentication

2. **Environment Setup**
   - Set Firebase project
   - Load environment configuration
   - Validate environment variables

3. **Testing** (unless skipped)
   - Run Flutter tests
   - Run Firebase Functions tests

4. **Build** (unless skipped)
   - Clean previous builds
   - Build Flutter web application
   - Optimize for target environment

5. **Deploy Components**
   - Deploy Firestore rules and indexes
   - Deploy Firebase Functions
   - Deploy web hosting

6. **Post-Deployment**
   - Seed development data (dev only)
   - Run health checks
   - Verify deployment

## Rollback Procedures

### Automatic Rollback
The scripts include automatic rollback triggers based on:
- Error rate > 5%
- Response time > 5 seconds
- Health check failures

### Manual Rollback
```bash
# Rollback hosting to previous version
firebase hosting:clone SOURCE_SITE_ID TARGET_SITE_ID

# Rollback functions
firebase functions:delete FUNCTION_NAME
firebase deploy --only functions

# Rollback Firestore rules (restore from backup)
firebase firestore:rules:release RULESET_ID
```

## Monitoring

### Health Checks
The scripts automatically verify:
- Application accessibility
- Firestore connectivity
- Authentication service
- API endpoints

### Performance Monitoring
- Response time tracking
- Error rate monitoring
- Resource usage alerts

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Make script executable
   chmod +x scripts/deploy-firebase.sh
   ```

2. **Firebase Not Logged In**
   ```bash
   firebase login
   ```

3. **Project Not Found**
   ```bash
   # Check available projects
   firebase projects:list
   
   # Set correct project
   firebase use PROJECT_ID
   ```

4. **Build Failures**
   ```bash
   # Clean and rebuild
   flutter clean
   flutter pub get
   flutter build web
   ```

5. **Firestore Rules Errors**
   ```bash
   # Test rules locally
   firebase emulators:start --only firestore
   ```

### Debug Mode

Enable debug output by setting environment variable:
```bash
export DEBUG=true
./scripts/deploy-firebase.sh -e staging
```

### Log Files

Deployment logs are saved to:
- Unix/Linux: `./logs/deployment-YYYY-MM-DD.log`
- Windows: `.\logs\deployment-YYYY-MM-DD.log`

## Security Considerations

### Production Deployments
- Always run security scans before production deployment
- Verify all environment variables are properly set
- Use secure credential storage (not in source code)
- Enable audit logging for production changes

### Access Control
- Limit production deployment access to authorized personnel
- Use separate Firebase projects for each environment
- Implement approval workflows for production changes

## Support

For deployment issues:
1. Check this README for common solutions
2. Review deployment logs
3. Check Firebase Console for errors
4. Contact the development team

## Script Maintenance

### Updating Scripts
1. Test changes in development environment first
2. Update both Unix and Windows versions
3. Update this documentation
4. Test on all supported platforms

### Version Control
- Keep scripts in version control
- Tag releases for rollback capability
- Document breaking changes
- Maintain backward compatibility when possible