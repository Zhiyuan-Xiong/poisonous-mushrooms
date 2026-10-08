@echo off
setlocal
cd /d "%~dp0"
start "" "%~dp0tools\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0."
exit /b 0
