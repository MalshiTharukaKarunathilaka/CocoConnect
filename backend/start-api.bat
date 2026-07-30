@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -Command "try { $r = Invoke-RestMethod 'http://localhost:8080/api/v1/health' -TimeoutSec 2; if ($r.ok) { exit 0 } } catch {}; exit 1" >nul 2>&1
if not errorlevel 1 (
  echo KapConnect API is already running.
  echo Health: http://localhost:8080/api/v1/health
  pause
  exit /b 0
)

where node >nul 2>&1
if errorlevel 1 (
  echo Node.js not found. Install Node.js 20+ and reopen this window.
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo Installing packages...
  call npm install
  if errorlevel 1 (
    echo npm install failed.
    pause
    exit /b 1
  )
)

if not exist ".env" (
  copy ".env.example" ".env" >nul
)

echo Setting up database...
call npx prisma generate
call npx prisma db push
call node prisma\seed.js

echo Starting KapConnect Express API on http://localhost:8080 ...
echo Demo OTP: 123456
call npm run dev
pause
