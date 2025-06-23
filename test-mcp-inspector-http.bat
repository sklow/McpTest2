@echo off
REM MCP Inspector HTTP transport test script for DotNetFrameworkMcpServer
REM This script tests the server using HTTP transport with MCP Inspector

chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================
echo   MCP Inspector HTTP Transport Test (Windows)
echo ================================================
echo.

REM Configuration
set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe"
set "SERVER_HOST=localhost"
set "SERVER_PORT=41114"
set "SERVER_PATH=/mcp"
set "SERVER_URL=http://!SERVER_HOST!:!SERVER_PORT!!SERVER_PATH!"

REM Check if the executable exists
if not exist "%EXE_PATH%" (
    echo Error: %EXE_PATH% not found!
    echo Please build the project first using:
    echo   build-debug.bat
    echo   or
    echo   dotnet build DotNetFrameworkMcpServer\DotNetFrameworkMcpServer.sln -c Debug
    echo.
    pause
    exit /b 1
)

REM Check if node/npm is available
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: npm is not installed!
    echo Please install Node.js and npm first.
    pause
    exit /b 1
)

REM Check if MCP Inspector is available
echo Checking MCP Inspector availability...
npx @modelcontextprotocol/inspector --help >nul 2>nul
if %errorlevel% neq 0 (
    echo Warning: MCP Inspector may not be available or installed.
    echo Will attempt to run anyway...
)

echo Starting DotNetFrameworkMcpServer with HTTP transport...
echo Server URL: !SERVER_URL!
echo Host: !SERVER_HOST!
echo Port: !SERVER_PORT!
echo Path: !SERVER_PATH!
echo.

REM Start the server in background
echo Starting server...
start "MCP Server" "%EXE_PATH%" --transport http --host "!SERVER_HOST!" --port "!SERVER_PORT!" --path "!SERVER_PATH!"

echo Server starting... waiting for initialization...
timeout /t 3 /nobreak >nul

REM Test server availability (optional, may not work on all Windows versions)
echo Testing server availability...
powershell -Command "try { Invoke-WebRequest -Uri '!SERVER_URL!' -Method Get -TimeoutSec 5 -ErrorAction Stop; Write-Host '✅ Server is responding at !SERVER_URL!' } catch { Write-Host '⚠️ Server may not be fully ready yet (this is normal)' }"
echo.

echo ========================================
echo   Starting MCP Inspector
echo ========================================
echo.
echo The MCP Inspector will open in your default web browser.
echo Server URL to test: !SERVER_URL!
echo.
echo To test the HTTP transport in the Inspector:
echo 1. Select 'Streamable HTTP' transport
echo 2. Enter Server URL: !SERVER_URL!
echo 3. Click 'Connect'
echo 4. Test tools/list method
echo.
echo Press Ctrl+C to stop the inspector.
echo Note: You may need to manually stop the server process after testing.
echo.
echo Starting MCP Inspector...

REM Start MCP Inspector
npx @modelcontextprotocol/inspector

echo.
echo MCP Inspector session ended.
echo.
echo Note: The MCP Server may still be running in the background.
echo If needed, use Task Manager to stop DotNetFrameworkMcpServer.exe
pause