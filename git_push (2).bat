@echo off
echo ================================
echo   Git Add, Commit and Push
echo ================================
echo.

:: ---- Check current branch ----
for /f "delims=" %%b in ('git branch --show-current') do set CURRENT_BRANCH=%%b

echo Current Branch: "%CURRENT_BRANCH%"
echo.

if "%CURRENT_BRANCH%"=="main-dev" (
    echo [BRANCH] You are already on "main-dev". No switch needed.
) else (
    echo [BRANCH] You are on "%CURRENT_BRANCH%". Switching to "main-dev"...

    :: Check if main-dev exists locally
    git branch --list main-dev | findstr "main-dev" >nul 2>&1
    if errorlevel 1 (
        echo [BRANCH] "main-dev" does not exist locally. Creating it now...
        git checkout -b main-dev
    ) else (
        echo [BRANCH] "main-dev" found locally. Switching...
        git checkout main-dev
    )

    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to switch to "main-dev" branch. Aborting.
        pause
        exit /b 1
    )

    for /f "delims=" %%b in ('git branch --show-current') do set CURRENT_BRANCH=%%b
    echo [BRANCH] Successfully switched to "%CURRENT_BRANCH%".
)

echo.
echo --------------------------------
:: ---- Commit message ----
set /p COMMIT_MSG=Enter commit message: 

if "%COMMIT_MSG%"=="" (
    echo.
    echo [ERROR] Commit message cannot be empty. Aborting.
    pause
    exit /b 1
)

echo.
echo --------------------------------
echo [1/3] Staging all changes...
git add .
if errorlevel 1 (
    echo [ERROR] git add failed. Aborting.
    pause
    exit /b 1
)
echo       Staging complete.

echo.
echo [2/3] Committing with message: "%COMMIT_MSG%"
git commit -m "%COMMIT_MSG%"
if errorlevel 1 (
    echo [ERROR] git commit failed. Aborting.
    pause
    exit /b 1
)

echo.
echo [3/3] Pushing to origin/main-dev...
git push origin main-dev
if errorlevel 1 (
    echo [ERROR] git push failed. Aborting.
    pause
    exit /b 1
)

echo.
echo ================================
echo   SUCCESS!
echo   Branch  : main-dev
echo   Message : %COMMIT_MSG%
echo   Pushed to origin/main-dev
echo ================================
echo.
pause
