@echo off
cd /d "%~dp0"
if not exist .env copy .env.example .env
echo Edit .env and fill in your settings before registering commands.
call npm ci
pause
