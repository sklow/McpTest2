@echo off
echo Building DotNetFrameworkMcpServer (Debug)...
echo.

REM Navigate to project directory
cd /d "%~dp0"

REM Clean previous build
echo Cleaning previous build...
dotnet clean DotNetFrameworkMcpServer\DotNetFrameworkMcpServer.sln -c Debug
if errorlevel 1 (
    echo Clean failed!
    pause
    exit /b 1
)

echo.
echo Building Debug configuration...
dotnet build DotNetFrameworkMcpServer\DotNetFrameworkMcpServer.sln -c Debug
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo Debug executable: DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe
echo.
pause