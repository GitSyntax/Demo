@echo off
echo ================================
echo   Git Add, Commit and Push
echo ================================

:: ---- Check current branch ----
for /f "delims=" %%b in ('git branch --show-current') do set CURRENT_BRANCH=%%b

if "%CURRENT_BRANCH%"=="main-dev" (
    echo [BRANCH] Already on main-dev.
) else (
    echo [BRANCH] Current branch is "%CURRENT_BRANCH%". Switching to main-dev...

    :: Check if main-dev exists locally
    git branch --list main-dev | findstr "main-dev" >nul 2>&1
    if errorlevel 1 (
        echo [BRANCH] main-dev does not exist. Creating and switching...
        git checkout -b main-dev
    ) else (
        echo [BRANCH] main-dev exists locally. Switching...
        git checkout main-dev
    )

    if errorlevel 1 (
        echo ERROR: Failed to switch to main-dev branch.
        pause
        exit /b 1
    )
)

echo.
:: ---- Commit message ----
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
