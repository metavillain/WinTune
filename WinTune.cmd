@echo off
rem Double-click to launch the WinTune GUI (it will ask for admin rights).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinTune.ps1" %*
