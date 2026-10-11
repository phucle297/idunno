@echo off
setlocal
if not exist "%~dp0Verify-Package.ps1" (
  echo Package verifier missing. Re-extract the complete ZIP into a writable local folder.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-Package.ps1"
if errorlevel 1 (
  pause
  exit /b 1
)
echo Starting Disaster Party. Use L for rooms; see PLAYTEST.txt for controls.
echo Logs: "%~dp0room-client.log". Never share passwords or admission tokens.
start "" /wait /d "%~dp0" "%~dp0DisasterParty.exe" --log-file "%~dp0room-client.log" %*
if errorlevel 1 (
  echo Game launch failed. Keep BUILD.txt and room-client.log for a bug report.
  pause
  exit /b 1
)
