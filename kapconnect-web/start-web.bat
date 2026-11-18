@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -Command "try { Invoke-WebRequest 'http://127.0.0.1:5173' -TimeoutSec 2 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 (
  echo KapConnect frontend is already running.
  echo Open: http://127.0.0.1:5173
  pause
  exit /b 0
)

where node >nul 2>&1
if errorlevel 1 (
  echo Node.js was not found. Install Node.js and reopen this window.
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo Installing frontend packages for the first time...
  call npm install
  if errorlevel 1 (
    echo Package installation failed.
    pause
    exit /b 1
  )
)

echo Starting KapConnect frontend on http://127.0.0.1:5173 ...
call npm run dev -- --host 127.0.0.1
pause
