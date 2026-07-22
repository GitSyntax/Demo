@echo off
title RequestFlow - Backend
echo =======================================
echo   RequestFlow Backend Starting...
echo =======================================
echo.

cd /d "%~dp0backend"

echo [1/6] Removing old virtual environment...
if exist venv (
    rmdir /s /q venv
    echo Old venv removed.
) else (
    echo No existing venv found.
)

echo [2/6] Creating virtual environment...
python -m venv venv

echo [3/6] Activating virtual environment...
call venv\Scripts\activate.bat

echo [4/6] Installing dependencies...
venv\Scripts\pip install --upgrade pip
venv\Scripts\pip install -r requirements.txt

echo [5/6] Running migrations...
venv\Scripts\python manage.py migrate

echo [6/6] Seeding master data...
venv\Scripts\python manage.py seed_masters

echo.
echo =======================================
echo   Creating Superuser (Admin Account)
echo   Please enter your desired credentials
echo =======================================
echo.
venv\Scripts\python manage.py createsuperuser

echo.
echo =======================================
echo   Backend running at:
echo   http://localhost:8000
echo   Swagger UI: http://localhost:8000/swagger/
echo =======================================
echo.

venv\Scripts\python manage.py runserver 0.0.0.0:8000

pause