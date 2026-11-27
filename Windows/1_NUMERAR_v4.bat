@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0renombrar_v4.ps1" -Modo Numerar -Carpeta "%~1"
pause
