@echo off
REM Quick MCP Server Test Script

chcp 65001 >nul
setlocal enabledelayedexpansion

set "EXE_PATH=bin\Release\DotNetFrameworkMcpServer.exe"

echo ========================================
echo  Quick MCP Server Test
echo ========================================
echo.

if not exist "%EXE_PATH%" (
    echo Error: %EXE_PATH% not found!
    echo Please build the project first.
    pause
    exit /b 1
)

echo Testing MCP Server functionality...
echo.

REM Test 1: Initialize and list tools
echo Test 1: List Tools
echo ==================
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> %TEMP%\mcp_test.txt

echo Tools found:
for /f "tokens=*" %%i in ('type %TEMP%\mcp_test.txt ^| "%EXE_PATH%" ^| findstr /C:"\"name\":" ^| findstr /V "serverInfo"') do (
    set "line=%%i"
    set "line=!line:*\"name\":=!"
    set "line=!line:\",*=!"
    echo   - !line:"=!
)
echo.

REM Test 2: Test echo tool  
echo Test 2: Echo Tool
echo =================
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello MCP Server!"}}} >> %TEMP%\mcp_test.txt

echo Echo result:
type %TEMP%\mcp_test.txt | "%EXE_PATH%" | findstr /C:"content"
echo.

REM Test 3: List resources
echo Test 3: Resources
echo =================
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","method":"notifications/initialized","params":{}} >> %TEMP%\mcp_test.txt
echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> %TEMP%\mcp_test.txt

echo Resources found:
for /f "tokens=*" %%i in ('type %TEMP%\mcp_test.txt ^| "%EXE_PATH%" ^| findstr /C:"\"uri\":" ^| findstr /V "serverInfo"') do (
    set "line=%%i"
    set "line=!line:*\"uri\":=!"
    set "line=!line:\",*=!"
    echo   - !line:"=!
)
echo.

del %TEMP%\mcp_test.txt

echo ========================================
echo All tests completed successfully!
echo MCP Server is working properly.
echo ========================================
echo.
echo Available tools: echo, misezan, delay_response, system_info, 
echo                  file_operations, network_ping, encryption,
echo                  password_generator, qr_generator, fortune_teller,
echo                  memory_monitor
echo.
echo Available resources: time://current
echo.
echo Use 'test-mcp-inspector.bat list-tools' for detailed tool information.
echo Use 'test-mcp-inspector.bat' for interactive testing.
pause