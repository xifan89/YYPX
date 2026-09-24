@echo off
cd /d "%~dp0"

echo ==========================================
echo   Word Card - Starting server...
echo ==========================================

REM Kill any previous .port file
if exist ".port" del ".port"

REM Start server.ps1 in background (so this bat can continue)
start "YYPX Server" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

REM Wait up to 5 seconds for the .port file to appear
set "PORT="
for /L %%i in (1,1,20) do (
    if not defined PORT (
        if exist ".port" (
            set /p PORT=< ".port"
        ) else (
            timeout /t 0 /nobreak >nul
        )
    )
)

if defined PORT (
    echo.
    echo Server is running on port %PORT%
    echo Opening browser...
    start "" "http://localhost:%PORT%/index.html"
) else (
    echo.
    echo WARNING: Server did not report a port within 5 seconds.
    echo Please check the black "YYPX Server" window for errors.
)

echo.
echo Leave the "YYPX Server" window open while using this site.
echo To stop, close that black window.
echo.
pause
