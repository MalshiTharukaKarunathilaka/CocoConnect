@echo off
setlocal
cd /d "%~dp0"

echo ========================================
echo       Starting KapConnect System
echo ========================================

rem Start the API only when it is not already healthy.
powershell -NoProfile -Command "try { $r = Invoke-RestMethod 'http://localhost:8080/api/v1/health' -TimeoutSec 2; if ($r.ok) { exit 0 } } catch {}; exit 1" >nul 2>&1
if errorlevel 1 (
  echo Starting backend API...
  start "KapConnect API" cmd /k call "%~dp0kapconnect-web\backend\start-api.bat"
  echo Waiting for the API...
  powershell -NoProfile -Command "$ok=$false; 1..30 | ForEach-Object { try { $r=Invoke-RestMethod 'http://localhost:8080/api/v1/health' -TimeoutSec 2; if ($r.ok) { $ok=$true; break } } catch {}; Start-Sleep -Seconds 2 }; if (-not $ok) { exit 1 }"
  if errorlevel 1 (
    echo The API did not start. Read the error in the "KapConnect API" window.
    pause
    exit /b 1
  )
) else (
  echo Backend API is already running.
)

rem Start the React website only when port 5173 is not already serving it.
powershell -NoProfile -Command "try { Invoke-WebRequest 'http://127.0.0.1:5173' -TimeoutSec 2 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
  echo Starting frontend website...
  start "KapConnect Frontend" cmd /k call "%~dp0kapconnect-web\start-web.bat"
  timeout /t 3 /nobreak >nul
) else (
  echo Frontend website is already running.
)

echo.
echo KapConnect is ready.
echo Website: http://127.0.0.1:5173
echo API health: http://localhost:8080/api/v1/health
echo Demo OTP: 123456
start "" "http://127.0.0.1:5173"
exit /b 0
