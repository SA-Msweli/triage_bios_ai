@echo off
REM Firebase Deployment Script for Triage-BIOS.ai (Windows)
REM This script handles deployment to different environments (dev, staging, prod)

setlocal enabledelayedexpansion

REM Default values
set ENVIRONMENT=dev
set SKIP_TESTS=false
set SKIP_BUILD=false
set DRY_RUN=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :args_parsed
if "%~1"=="-e" (
    set ENVIRONMENT=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="--environment" (
    set ENVIRONMENT=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="-s" (
    set SKIP_TESTS=true
    shift
    goto :parse_args
)
if "%~1"=="--skip-tests" (
    set SKIP_TESTS=true
    shift
    goto :parse_args
)
if "%~1"=="-b" (
    set SKIP_BUILD=true
    shift
    goto :parse_args
)
if "%~1"=="--skip-build" (
    set SKIP_BUILD=true
    shift
    goto :parse_args
)
if "%~1"=="-d" (
    set DRY_RUN=true
    shift
    goto :parse_args
)
if "%~1"=="--dry-run" (
    set DRY_RUN=true
    shift
    goto :parse_args
)
if "%~1"=="-h" goto :show_usage
if "%~1"=="--help" goto :show_usage
echo [ERROR] Unknown option: %~1
goto :show_usage

:args_parsed

REM Validate environment
if not "%ENVIRONMENT%"=="dev" if not "%ENVIRONMENT%"=="staging" if not "%ENVIRONMENT%"=="prod" (
    echo [ERROR] Invalid environment: %ENVIRONMENT%. Must be dev, staging, or prod.
    exit /b 1
)

echo [INFO] Starting deployment to %ENVIRONMENT% environment...

REM Check prerequisites
call :check_prerequisites
if errorlevel 1 exit /b 1

REM Set environment configuration
call :set_environment
if errorlevel 1 exit /b 1

REM Run tests
call :run_tests
if errorlevel 1 exit /b 1

REM Build application
call :build_application
if errorlevel 1 exit /b 1

REM Deploy components
call :deploy_firestore
if errorlevel 1 exit /b 1

call :deploy_functions
if errorlevel 1 exit /b 1

call :deploy_hosting
if errorlevel 1 exit /b 1

REM Seed data for dev environment
call :seed_data
if errorlevel 1 exit /b 1

REM Verify deployment
call :verify_deployment
if errorlevel 1 exit /b 1

echo [SUCCESS] === Deployment Complete ===
echo [SUCCESS] Environment: %ENVIRONMENT%
echo [SUCCESS] Timestamp: %date% %time%
echo [SUCCESS] ============================
goto :eof

:show_usage
echo Usage: %0 [OPTIONS]
echo.
echo Options:
echo   -e, --environment ENV    Target environment (dev^|staging^|prod) [default: dev]
echo   -s, --skip-tests        Skip running tests before deployment
echo   -b, --skip-build        Skip building the application
echo   -d, --dry-run           Show what would be deployed without actually deploying
echo   -h, --help              Show this help message
echo.
echo Examples:
echo   %0 -e staging           Deploy to staging environment
echo   %0 -e prod -s           Deploy to production, skipping tests
echo   %0 -d                   Dry run for development environment
exit /b 0

:check_prerequisites
echo [INFO] Checking prerequisites...

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Firebase CLI is not installed. Please install it first:
    echo [ERROR] npm install -g firebase-tools
    exit /b 1
)

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter is not installed. Please install Flutter first.
    exit /b 1
)

REM Check if logged into Firebase
firebase projects:list >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Not logged into Firebase. Please run: firebase login
    exit /b 1
)

echo [SUCCESS] Prerequisites check passed
goto :eof

:set_environment
echo [INFO] Setting up environment configuration for %ENVIRONMENT%...

if "%ENVIRONMENT%"=="dev" (
    set FIREBASE_PROJECT=triage-bios-dev
    set FLUTTER_ENV=development
) else if "%ENVIRONMENT%"=="staging" (
    set FIREBASE_PROJECT=triage-bios-staging
    set FLUTTER_ENV=staging
) else if "%ENVIRONMENT%"=="prod" (
    set FIREBASE_PROJECT=triage-bios-prod
    set FLUTTER_ENV=production
)

REM Set Firebase project
firebase use %FIREBASE_PROJECT%
if errorlevel 1 (
    echo [ERROR] Failed to set Firebase project to %FIREBASE_PROJECT%
    exit /b 1
)

echo [SUCCESS] Environment set to %ENVIRONMENT% (project: %FIREBASE_PROJECT%)
goto :eof

:run_tests
if "%SKIP_TESTS%"=="true" (
    echo [WARNING] Skipping tests as requested
    goto :eof
)

echo [INFO] Running tests...

REM Run Flutter tests
flutter test
if errorlevel 1 (
    echo [ERROR] Flutter tests failed
    exit /b 1
)

REM Run Firebase Functions tests (if they exist)
if exist "functions\package.json" (
    cd functions
    npm test
    if errorlevel 1 (
        echo [ERROR] Firebase Functions tests failed
        cd ..
        exit /b 1
    )
    cd ..
)

echo [SUCCESS] All tests passed
goto :eof

:build_application
if "%SKIP_BUILD%"=="true" (
    echo [WARNING] Skipping build as requested
    goto :eof
)

echo [INFO] Building application for %ENVIRONMENT%...

REM Clean previous builds
flutter clean
flutter pub get

REM Build for web
flutter build web --dart-define=ENVIRONMENT=%FLUTTER_ENV%
if errorlevel 1 (
    echo [ERROR] Flutter build failed
    exit /b 1
)

echo [SUCCESS] Application built successfully
goto :eof

:deploy_firestore
echo [INFO] Deploying Firestore rules and indexes...

if "%DRY_RUN%"=="true" (
    echo [WARNING] DRY RUN: Would deploy Firestore rules and indexes
    goto :eof
)

firebase deploy --only firestore:rules,firestore:indexes
if errorlevel 1 (
    echo [ERROR] Firestore deployment failed
    exit /b 1
)

echo [SUCCESS] Firestore rules and indexes deployed
goto :eof

:deploy_functions
if not exist "functions" (
    echo [WARNING] No functions directory found, skipping functions deployment
    goto :eof
)

echo [INFO] Deploying Firebase Functions...

if "%DRY_RUN%"=="true" (
    echo [WARNING] DRY RUN: Would deploy Firebase Functions
    goto :eof
)

REM Install dependencies
cd functions
npm ci
if errorlevel 1 (
    echo [ERROR] Failed to install function dependencies
    cd ..
    exit /b 1
)
cd ..

firebase deploy --only functions
if errorlevel 1 (
    echo [ERROR] Firebase Functions deployment failed
    exit /b 1
)

echo [SUCCESS] Firebase Functions deployed
goto :eof

:deploy_hosting
echo [INFO] Deploying web application...

if "%DRY_RUN%"=="true" (
    echo [WARNING] DRY RUN: Would deploy web application
    goto :eof
)

firebase deploy --only hosting
if errorlevel 1 (
    echo [ERROR] Web application deployment failed
    exit /b 1
)

echo [SUCCESS] Web application deployed
goto :eof

:seed_data
if not "%ENVIRONMENT%"=="dev" goto :eof

echo [INFO] Seeding development data...

if "%DRY_RUN%"=="true" (
    echo [WARNING] DRY RUN: Would seed development data
    goto :eof
)

REM Run data seeding script
if exist "scripts\seed-data.js" (
    node scripts\seed-data.js
    if errorlevel 1 (
        echo [ERROR] Data seeding failed
        exit /b 1
    )
    echo [SUCCESS] Development data seeded
) else (
    echo [WARNING] No data seeding script found
)
goto :eof

:verify_deployment
echo [INFO] Verifying deployment...

REM Basic verification - check if Firebase project is accessible
firebase projects:list | findstr %FIREBASE_PROJECT% >nul
if errorlevel 1 (
    echo [ERROR] Deployment verification failed - project not accessible
    exit /b 1
)

echo [SUCCESS] Deployment verification passed
echo [SUCCESS] Check Firebase Console for deployment details
goto :eof