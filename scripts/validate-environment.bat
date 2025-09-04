@echo off
REM Environment Validation Script for Triage-BIOS.ai (Windows)
REM This script validates that the deployment environment is properly configured

setlocal enabledelayedexpansion
set ENVIRONMENT=%1
if "%ENVIRONMENT%"=="" set ENVIRONMENT=dev
set ERRORS=0

echo [INFO] Validating environment: %ENVIRONMENT%
echo ==================================

REM Check Firebase CLI
firebase --version >nul 2>&1
if errorlevel 1 (
    echo [X] Firebase CLI not installed
    set /a ERRORS+=1
) else (
    for /f "tokens=*" %%i in ('firebase --version 2^>nul') do set FIREBASE_VERSION=%%i
    echo [✓] Firebase CLI installed: !FIREBASE_VERSION!
)

REM Check Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [X] Flutter not installed
    set /a ERRORS+=1
) else (
    for /f "tokens=*" %%i in ('flutter --version 2^>nul ^| findstr "Flutter"') do set FLUTTER_VERSION=%%i
    echo [✓] Flutter installed: !FLUTTER_VERSION!
)

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [⚠] Node.js not found (required for Firebase Functions)
) else (
    for /f "tokens=*" %%i in ('node --version 2^>nul') do set NODE_VERSION=%%i
    echo [✓] Node.js installed: !NODE_VERSION!
)

REM Check Firebase authentication
firebase projects:list >nul 2>&1
if errorlevel 1 (
    echo [X] Firebase authentication failed - run 'firebase login'
    set /a ERRORS+=1
) else (
    echo [✓] Firebase authentication valid
)

REM Check environment file
set ENV_FILE=.env.%ENVIRONMENT%
if exist "%ENV_FILE%" (
    echo [✓] Environment file found: %ENV_FILE%
    
    REM Check required variables
    findstr /B "FIREBASE_PROJECT_ID=" "%ENV_FILE%" >nul
    if errorlevel 1 (
        echo [X] Missing required variable: FIREBASE_PROJECT_ID in %ENV_FILE%
        set /a ERRORS+=1
    ) else (
        echo [✓] Required variable found: FIREBASE_PROJECT_ID
    )
    
    findstr /B "FIREBASE_API_KEY=" "%ENV_FILE%" >nul
    if errorlevel 1 (
        echo [X] Missing required variable: FIREBASE_API_KEY in %ENV_FILE%
        set /a ERRORS+=1
    ) else (
        echo [✓] Required variable found: FIREBASE_API_KEY
    )
) else (
    echo [X] Environment file not found: %ENV_FILE%
    echo [INFO] Copy from template: copy config\env.%ENVIRONMENT%.template %ENV_FILE%
    set /a ERRORS+=1
)

REM Check Firebase project configuration
if exist "firebase.json" (
    echo [✓] Firebase configuration found
) else (
    echo [⚠] Firebase configuration not found - run 'firebase init'
)

REM Check Firestore rules
if exist "firestore.rules" (
    echo [✓] Firestore rules found
) else (
    echo [⚠] Firestore rules not found
)

REM Check Flutter dependencies
if exist "pubspec.yaml" (
    echo [✓] Flutter project configuration found
    
    if exist ".dart_tool" (
        echo [✓] Flutter dependencies installed
    ) else (
        echo [⚠] Flutter dependencies not installed - run 'flutter pub get'
    )
) else (
    echo [X] Flutter project not found (pubspec.yaml missing)
    set /a ERRORS+=1
)

REM Check build directory
if exist "build\web" (
    echo [✓] Web build directory exists
) else (
    echo [⚠] Web build not found - will build during deployment
)

echo ==================================

if %ERRORS%==0 (
    echo [✓] Environment validation passed! Ready for deployment.
    exit /b 0
) else (
    echo [X] Environment validation failed with %ERRORS% error(s).
    echo [INFO] Please fix the errors above before deploying.
    exit /b 1
)