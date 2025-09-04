@echo off
echo Firebase Deployment for Windows - Triage BIOS AI
echo Project ID: triagebiosai-471108
echo.
echo Running PowerShell deployment script...
powershell -ExecutionPolicy Bypass -File "deploy.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Deployment failed! Check the output above for errors.
    echo Make sure you have:
    echo - Google Cloud SDK installed and authenticated
    echo - Firebase CLI installed
    echo - Flutter SDK installed
    echo - .env file configured with proper API keys
)
pause