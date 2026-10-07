@echo off
title Craveo Food Delivery AI Server
cd /d "%~dp0"
echo ====================================================
echo Starting Craveo Food Delivery AI Server...
echo ====================================================
echo Opening http://127.0.0.1:8000 in your browser...
start http://127.0.0.1:8000/
echo.
echo Running Django server... (Press Ctrl+C to stop)
call "venv\Scripts\python.exe" manage.py runserver 127.0.0.1:8000
pause
