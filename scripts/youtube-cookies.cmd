@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0youtube-cookies.ps1" %*
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" echo Cookies were NOT exported (see the message above).
pause
exit /b %RESULT%
