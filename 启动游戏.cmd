@echo off
setlocal
cd /d "%~dp0"
echo Preparing Poison Mushroom...
"%~dp0tools\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --path "%~dp0." --import --quit
if errorlevel 1 (
  echo Godot could not import this project. Please keep the whole project folder together.
  pause
  exit /b 1
)
start "" "%~dp0tools\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
exit /b 0
