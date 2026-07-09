@echo off
echo ================================
echo   Git Add, Commit and Push
echo ================================

set /p COMMIT_MSG=Enter commit message: 

if "%COMMIT_MSG%"=="" (
    echo ERROR: Commit message cannot be empty.
    pause
    exit /b 1
)

echo.
echo [1/3] Staging all changes...
git add .

echo [2/3] Committing with message: "%COMMIT_MSG%"
git commit -m "%COMMIT_MSG%"

echo [3/3] Pushing to origin main-dev...
git push origin main-dev

echo.
echo Done!
pause
