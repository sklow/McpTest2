@echo off
chcp 65001 >nul
REM MCP Tool Testing Script for DotNetFrameworkMcpServer
REM This script provides comprehensive testing functionality for MCP tools

setlocal enabledelayedexpansion

set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe"

echo ========================================
echo   MCP Tool Testing Script
echo ========================================
echo.

REM Parse command line arguments
set "COMMAND=%~1"
if "%COMMAND%"=="" set "COMMAND=help"

goto %COMMAND% 2>nul || goto unknown_command

:check
    call :check_prerequisites
    goto :eof

:connectivity
    call :check_prerequisites
    call :test_connectivity
    goto :eof

:list-tools
    call :check_prerequisites
    call :list_tools
    goto :eof

:list-resources
    call :check_prerequisites
    call :list_resources
    goto :eof

:call-tool
    if "%~2"=="" (
        echo Error: Tool name required
        echo Usage: %0 call-tool TOOL_NAME [--arg key=value ...]
        exit /b 1
    )
    call :check_prerequisites
    call :call_tool %*
    goto :eof

:read-resource
    if "%~2"=="" (
        echo Error: Resource URI required
        echo Usage: %0 read-resource RESOURCE_URI
        exit /b 1
    )
    call :check_prerequisites
    call :read_resource "%~2"
    goto :eof

:test-all
    call :check_prerequisites
    call :run_tests
    goto :eof

:start-http
    call :check_prerequisites
    call :start_http_server
    goto :eof

:test-http
    call :test_http_endpoint
    goto :eof

:help
    call :show_usage
    goto :eof

:unknown_command
    echo Unknown command: %COMMAND%
    echo Use '%0 help' for usage information
    exit /b 1

REM ============ Subroutines ============

:check_prerequisites
    REM Check if the executable exists
    if not exist "%EXE_PATH%" (
        echo Error: %EXE_PATH% not found!
        echo Please build the project first using:
        echo   dotnet build DotNetFrameworkMcpServer.sln -c Debug
        echo.
        exit /b 1
    )
    echo Found executable: %EXE_PATH%
    goto :eof

:test_connectivity
    echo Testing server connectivity...
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    findstr /C:"serverInfo" "%TEMP%\mcp_response.txt" >nul
    if errorlevel 1 (
        echo ✗ Server connectivity test failed
        echo Response:
        type "%TEMP%\mcp_response.txt"
    ) else (
        echo ✓ Server connectivity test passed
    )
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:list_tools
    echo === Available Tools ===
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    echo Tool Names:
    echo -----------
    for /f "tokens=*" %%i in ('findstr /C:"\"name\":" "%TEMP%\mcp_response.txt"') do (
        set "line=%%i"
        set "line=!line:*\"name\":=!"
        set "line=!line:\",*=!"
        set "line=!line:\"=!"
        set "line=!line: =!"
        echo   ■ !line!
    )
    
    echo.
    echo Raw JSON Response:
    echo ------------------
    type "%TEMP%\mcp_response.txt"
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:list_resources
    echo === Available Resources ===
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    echo Resource URIs:
    echo --------------
    for /f "tokens=*" %%i in ('findstr /C:"\"uri\":" "%TEMP%\mcp_response.txt"') do (
        set "line=%%i"
        set "line=!line:*\"uri\":=!"
        set "line=!line:\",*=!"
        set "line=!line:\"=!"
        set "line=!line: =!"
        echo   ■ !line!
    )
    
    echo.
    echo Raw JSON Response:
    echo ------------------
    type "%TEMP%\mcp_response.txt"
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:call_tool
    shift
    set "tool_name=%~1"
    shift
    set "args="
    
    :parse_args
    if "%~1"=="" goto call_tool_execute
    if "%~1"=="--arg" (
        set "args=!args! --tool-arg %~2"
        shift
        shift
        goto parse_args
    )
    set "args=!args! %~1"
    shift
    goto parse_args
    
    :call_tool_execute
    echo === Calling Tool: %tool_name% ===
    
    REM Build JSON arguments object
    set "json_args={}"
    if not "!args!"=="" (
        set "json_args=!args!"
        set "json_args=!json_args: --tool-arg =,"!"
        set "json_args=!json_args:==":!"
        set "json_args={!json_args:~1!}"
        set "json_args=!json_args:,=,"!"
    )
    
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%tool_name%","arguments":!json_args!}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    echo Tool Response:
    echo ---------------
    type "%TEMP%\mcp_response.txt"
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:read_resource
    set "resource_uri=%~1"
    echo === Reading Resource: %resource_uri% ===
    
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"%resource_uri%"}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    echo Resource Content:
    echo ------------------
    type "%TEMP%\mcp_response.txt"
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:run_tests
    echo === Running Predefined Tests ===
    
    echo Testing echo tool...
    call :run_single_test echo "{\"message\":\"Hello from MCP test!\"}"
    
    echo Testing system_info tool...
    call :run_single_test system_info "{\"info_type\":\"os\"}"
    
    echo Testing misezan tool...
    call :run_single_test misezan "{\"num1\":5,\"num2\":3}"
    
    echo Testing delay_response tool...
    call :run_single_test delay_response "{\"seconds\":2,\"message\":\"Delayed response test\"}"
    
    echo Testing password_generator tool...
    call :run_single_test password_generator "{\"length\":16,\"include_symbols\":true}"
    
    echo Testing fortune_teller tool...
    call :run_single_test fortune_teller "{\"name\":\"TestUser\",\"category\":\"general\"}"
    
    echo Testing current time resource...
    call :test_resource "time://current"
    
    echo ✓ All predefined tests completed
    goto :eof

:run_single_test
    set "test_tool=%~1"
    set "test_args=%~2"
    
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%test_tool%","arguments":%test_args%}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    findstr /C:"content" "%TEMP%\mcp_response.txt" >nul
    if errorlevel 1 (
        echo ✗ %test_tool% failed
        type "%TEMP%\mcp_response.txt"
    ) else (
        echo ✓ %test_tool% passed
    )
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:test_resource
    set "test_uri=%~1"
    
    echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_test.txt"
    echo {"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"%test_uri%"}} >> "%TEMP%\mcp_test.txt"
    
    type "%TEMP%\mcp_test.txt" | "%EXE_PATH%" > "%TEMP%\mcp_response.txt" 2>&1
    
    findstr /C:"contents" "%TEMP%\mcp_response.txt" >nul
    if errorlevel 1 (
        echo ✗ Resource %test_uri% failed
        type "%TEMP%\mcp_response.txt"
    ) else (
        echo ✓ Resource %test_uri% passed
    )
    
    del "%TEMP%\mcp_test.txt" "%TEMP%\mcp_response.txt" 2>nul
    echo.
    goto :eof

:start_http_server
    echo Starting HTTP/SSE server for testing...
    echo Server will be available at: http://localhost:41114
    echo Press Ctrl+C to stop the server
    echo.
    
    REM Start server in HTTP mode
    "%EXE_PATH%" http
    goto :eof

:test_http_endpoint
    echo === Testing HTTP/SSE Endpoint ===
    echo Make sure the server is running in HTTP mode first!
    echo.
    echo To test HTTP endpoint, use the following commands:
    echo   curl -X POST http://localhost:41114/sse -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}"
    echo.
    echo Or if you have MCP Inspector installed:
    echo   npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/list
    echo.
    goto :eof

:show_usage
    echo MCP Tool Testing Script
    echo.
    echo Usage: %0 [COMMAND] [OPTIONS]
    echo.
    echo Commands:
    echo   check               Check prerequisites
    echo   connectivity        Test server connectivity
    echo   list-tools          List all available tools
    echo   list-resources      List all available resources
    echo   call-tool TOOL      Call a specific tool with arguments
    echo   read-resource URI   Read a specific resource
    echo   test-all           Run all predefined tests
    echo   start-http         Start HTTP/SSE server
    echo   test-http          Show HTTP/SSE testing instructions
    echo   help               Show this help message
    echo.
    echo Tool Call Examples:
    echo   %0 call-tool echo --arg message="Hello World"
    echo   %0 call-tool system_info --arg info_type=memory
    echo   %0 call-tool misezan --arg num1=6 --arg num2=9
    echo   %0 call-tool delay_response --arg seconds=3 --arg message="Test"
    echo   %0 call-tool password_generator --arg length=20 --arg include_symbols=false
    echo   %0 call-tool network_ping --arg hostname=example.com --arg count=3
    echo   %0 call-tool fortune_teller --arg name="Alice" --arg category=love
    echo   %0 call-tool file_operations --arg operation=create --arg filename=test.txt --arg content="Test content"
    echo   %0 call-tool encryption --arg operation=encrypt --arg text="secret" --arg password="mypass"
    echo   %0 call-tool qr_generator --arg text="https://example.com" --arg size=25
    echo   %0 call-tool memory_monitor --arg duration=5
    echo.
    echo Resource Examples:
    echo   %0 read-resource "time://current"
    echo.
    echo HTTP/SSE Testing:
    echo   # Start server in HTTP mode (separate terminal)
    echo   %0 start-http
    echo   
    echo   # Test HTTP endpoint with curl (another terminal)
    echo   curl -X POST http://localhost:41114/sse -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}"
    echo.
    echo Note: This script uses direct JSON-RPC communication over STDIO instead of MCP Inspector
    echo      to avoid dependency issues. All functionality works the same way.
    goto :eof