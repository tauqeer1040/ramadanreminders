@echo off
REM Daily auto-backup wrapper for Windows Task Scheduler.
REM Calls the bash script from the project root.

cd /d C:\Users\tau\code\ramadan_app
bash scripts\auto-backup.sh >> logs\backup.log 2>&1
