@echo off
REM MCP Inspector test script for DotNetFrameworkMcpServer
REM This script runs the MCP Inspector with the built DotNetFrameworkMcpServer.exe

chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo  MCP Inspector Test Script
echo ========================================
echo.

REM Check if the executable exists
set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe"
if not exist "%EXE_PATH%" (
    echo Error: %EXE_PATH% not found!
    echo Please build the project first using:
    echo   dotnet build DotNetFrameworkMcpServer.sln -c Debug
    echo.
    pause
    exit /b 1
)

REM Skip MCP Inspector check for simple commands
set "METHOD=%~1"
if "%METHOD%"=="list-tools" goto direct_mode
if "%METHOD%"=="list-resources" goto direct_mode
if "%METHOD%"=="test-echo" goto direct_mode

REM Check if MCP Inspector is installed (only for interactive mode)
echo Checking MCP Inspector availability...
npx @modelcontextprotocol/inspector --version >nul 2>&1
if errorlevel 1 (
    echo MCP Inspector not found. Using direct protocol mode instead.
    echo For interactive testing, please install MCP Inspector manually:
    echo   npm install -g @modelcontextprotocol/inspector
    echo.
    echo Continuing with direct protocol testing...
    goto direct_mode
)

REM Parse command line arguments
if "%~1"=="" (
    REM No arguments - run interactive inspector
    echo Starting interactive MCP Inspector with DotNetFrameworkMcpServer...
    echo Executable: %EXE_PATH%
    echo Mode: STDIO (default)
    echo.
    echo The inspector will open in your default web browser.
    echo Press Ctrl+C to stop the inspector.
    echo.
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%"
) else (
    REM Arguments provided - run specific method using direct protocol
    set "METHOD=%~1"
    echo Running MCP method: %METHOD%
    echo Executable: %EXE_PATH%
    echo.
    
    if "%METHOD%"=="list-tools" (
        echo Testing tools list...
        echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> %TEMP%\mcp_input.txt
        echo.
        echo Available Tools:
        echo ================
        for /f "tokens=*" %%i in ('type %TEMP%\mcp_input.txt ^| "%EXE_PATH%" ^| findstr /C:"\"name\":" ^| findstr /V "serverInfo"') do (
            echo %%i
        )
        echo.
        echo Full Response:
        echo ==============
        type %TEMP%\mcp_input.txt | "%EXE_PATH%"
        del %TEMP%\mcp_input.txt
    ) else if "%METHOD%"=="list-resources" (
        echo Testing resources list...
        echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> %TEMP%\mcp_input.txt
        echo.
        echo Available Resources:
        echo ===================
        type %TEMP%\mcp_input.txt | "%EXE_PATH%"
        del %TEMP%\mcp_input.txt
    ) else if "%METHOD%"=="test-echo" (
        echo Testing echo tool...
        echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> %TEMP%\mcp_input.txt
        echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello from test!"}}} >> %TEMP%\mcp_input.txt
        echo.
        echo Echo Test Result:
        echo ================
        type %TEMP%\mcp_input.txt | "%EXE_PATH%"
        del %TEMP%\mcp_input.txt
    ) else (
        echo Unknown method: %METHOD%
        echo.
        echo Available methods:
        echo   list-tools     - List all available tools
        echo   list-resources - List all available resources  
        echo   test-echo      - Test the echo tool
        echo.
        echo Usage: %0 [method]
        echo   %0                  ^(interactive mode^)
        echo   %0 list-tools
        echo   %0 list-resources
        echo   %0 test-echo
    )
)

goto end_script

:direct_mode
REM Direct protocol mode without MCP Inspector
set "METHOD=%~1"
echo Running in direct protocol mode...
echo Method: %METHOD%
echo Executable: %EXE_PATH%
echo.

if "%METHOD%"=="list-tools" (
    echo Testing tools list...
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> "%TEMP%\mcp_input.txt"
    echo.
    echo ========================================
    echo Available Tools:
    echo ========================================
    type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"
    
    echo Tool Names:
    echo -----------
    for /f "tokens=*" %%i in ('findstr /C:"\"name\":" "%TEMP%\mcp_output.txt"') do (
        set "line=%%i"
        set "line=!line:*\"name\":=!"
        set "line=!line:\",*=!"
        set "line=!line:\"=!"
        set "line=!line: =!"
        echo   ■ !line!
    )
    echo.
    echo Full JSON Response:
    echo ------------------
    type "%TEMP%\mcp_output.txt"
    del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"

) else if "%METHOD%"=="list-resources" (
    echo Testing resources list...
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> "%TEMP%\mcp_input.txt"
    echo.
    echo ========================================
    echo Available Resources:
    echo ========================================
    type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"
    
    echo Resource URIs:
    echo -------------
    for /f "tokens=*" %%i in ('findstr /C:"\"uri\":" "%TEMP%\mcp_output.txt"') do (
        set "line=%%i"
        set "line=!line:*\"uri\":=!"
        set "line=!line:\",*=!"
        set "line=!line:\"=!"
        set "line=!line: =!"
        echo   ■ !line!
    )
    echo.
    echo Full JSON Response:
    echo ------------------
    type "%TEMP%\mcp_output.txt"
    del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"

) else if "%METHOD%"=="test-echo" (
    echo Testing echo tool...
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello from test!"}}} >> "%TEMP%\mcp_input.txt"
    echo.
    echo ========================================
    echo Echo Test Result:
    echo ========================================
    type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"
    type "%TEMP%\mcp_output.txt"
    del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"

) else (
    echo No valid method specified for direct mode.
    echo Use: list-tools, list-resources, or test-echo
)

:end_script
echo.
echo MCP Inspector session ended.
if "%~1"=="" pause