@echo off
title RequestFlow - Frontend
echo =======================================
echo   RequestFlow Frontend Starting...
echo =======================================
echo.

echo Current directory: %~dp0
echo.

cd /d "%~dp0frontend"
if %errorlevel% neq 0 (
    echo ERROR: Could not find frontend folder!
    echo Looked in: %~dp0frontend
    pause
    exit /b 1
)

echo Entered: %cd%
echo.

echo [1/4] Removing old node_modules (if any)...
if exist node_modules (
    rmdir /s /q node_modules
    echo Old node_modules removed.
) else (
    echo No existing node_modules found.
)
echo.

echo [2/4] Setting up .env file...
if not exist .env (
    if exist .env.example (
        copy .env.example .env
        echo .env file created.
    ) else (
        echo WARNING: .env.example not found, creating default .env...
        echo VITE_API_BASE_URL=http://localhost:8000 > .env
    )
) else (
    echo .env already exists, skipping...
)
echo.

echo [3/4] Installing dependencies...
call npm install
if %errorlevel% neq 0 (
    echo.
    echo ERROR: npm install failed! See above for details.
    pause
    exit /b 1
)
echo.

echo [4/4] Starting development server...
echo.
echo =======================================
echo   Frontend running at:
echo   http://localhost:5173
echo =======================================
echo.

call npm run dev

echo.
echo Server stopped.
pause
