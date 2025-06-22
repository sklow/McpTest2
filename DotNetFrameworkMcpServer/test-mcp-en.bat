@echo off
REM English MCP Server Test Script - No Japanese characters

chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo  MCP Server Test (English)
echo ========================================
echo.

REM Check if the executable exists
set "EXE_PATH=bin\Release\DotNetFrameworkMcpServer.exe"
if not exist "%EXE_PATH%" (
    echo Error: %EXE_PATH% not found!
    echo Please build the project first using:
    echo   dotnet build DotNetFrameworkMcpServer.sln -c Release
    echo.
    pause
    exit /b 1
)

echo Found executable: %EXE_PATH%
echo.

REM Parse command line arguments
set "METHOD=%~1"
if "%METHOD%"=="" set "METHOD=help"

if "%METHOD%"=="list-tools" goto list_tools
if "%METHOD%"=="list-resources" goto list_resources
if "%METHOD%"=="test-echo" goto test_echo
if "%METHOD%"=="test-system" goto test_system
if "%METHOD%"=="help" goto show_help
goto unknown_method

:list_tools
echo Retrieving tools list...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo Available Tools:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

REM Parse and display tool names
echo.
echo Tool Names:
echo -----------
for /f "tokens=*" %%i in ('findstr /C:"\"name\":" "%TEMP%\mcp_output.txt"') do (
    set "line=%%i"
    set "line=!line:*\"name\":=!"
    set "line=!line:\",*=!"
    set "line=!line:\"=!"
    set "line=!line: =!"
    echo   [*] !line!
)

echo.
echo Tool Count and Details:
echo ----------------------
findstr /C:"\"name\":" "%TEMP%\mcp_output.txt" | find /C "name"
echo tools found.

echo.
echo Raw JSON Response (first 500 chars):
echo ------------------------------------
type "%TEMP%\mcp_output.txt" | more

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:list_resources
echo Retrieving resources list...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo Available Resources:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo Resource URIs:
echo --------------
for /f "tokens=*" %%i in ('findstr /C:"\"uri\":" "%TEMP%\mcp_output.txt"') do (
    set "line=%%i"
    set "line=!line:*\"uri\":=!"
    set "line=!line:\",*=!"
    set "line=!line:\"=!"
    set "line=!line: =!"
    echo   [*] !line!
)

echo.
echo Raw JSON Response:
echo ------------------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:test_echo
echo Testing echo tool...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello from MCP test!"}}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo Echo Tool Test:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo Response:
echo ---------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:test_system
echo Testing system_info tool...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"system_info","arguments":{"info_type":"os"}}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo System Info Tool Test:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo Response:
echo ---------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:show_help
echo Usage: %0 [COMMAND]
echo.
echo Commands:
echo   list-tools      - List all available tools
echo   list-resources  - List all available resources
echo   test-echo       - Test the echo tool
echo   test-system     - Test the system_info tool
echo   help            - Show this help message
echo.
echo Examples:
echo   %0 list-tools
echo   %0 list-resources
echo   %0 test-echo
echo   %0 test-system
echo.
echo Expected Tools (11 total):
echo   echo, misezan, delay_response, system_info,
echo   file_operations, network_ping, encryption,
echo   password_generator, qr_generator, fortune_teller,
echo   memory_monitor
echo.
echo Expected Resources:
echo   time://current
goto end

:unknown_method
echo Unknown command: %METHOD%
echo.
echo Use '%0 help' for usage information.
goto end

:end
echo.
echo ========================================
echo Test completed.
echo ========================================
pause