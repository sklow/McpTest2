@echo off
REM MCP Tool Testing Script for DotNetFrameworkMcpServer
REM This script provides comprehensive testing functionality for MCP tools

setlocal enabledelayedexpansion

set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Release\DotNetFrameworkMcpServer.exe"

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
        echo   dotnet build DotNetFrameworkMcpServer.sln -c Release
        echo.
        exit /b 1
    )

    REM Check if MCP Inspector is installed
    npx @modelcontextprotocol/inspector --version >nul 2>&1
    if errorlevel 1 (
        echo MCP Inspector not found. Installing...
        npm install -g @modelcontextprotocol/inspector
        if errorlevel 1 (
            echo Failed to install MCP Inspector!
            exit /b 1
        )
    )
    goto :eof

:test_connectivity
    echo Testing server connectivity...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method initialize --timeout 10
    echo ✓ Server connectivity test passed
    echo.
    goto :eof

:list_tools
    echo === Available Tools ===
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/list
    echo.
    goto :eof

:list_resources
    echo === Available Resources ===
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method resources/list
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
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name %tool_name% !args!
    echo.
    goto :eof

:read_resource
    set "resource_uri=%~1"
    echo === Reading Resource: %resource_uri% ===
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method resources/read --resource-uri %resource_uri%
    echo.
    goto :eof

:run_tests
    echo === Running Predefined Tests ===
    
    echo Testing echo tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name echo --tool-arg message="Hello from MCP test!"
    
    echo Testing system_info tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name system_info --tool-arg info_type=os
    
    echo Testing misezan tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name misezan --tool-arg num1=5 --tool-arg num2=3
    
    echo Testing delay_response tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name delay_response --tool-arg seconds=2 --tool-arg message="Delayed response test"
    
    echo Testing password_generator tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name password_generator --tool-arg length=16 --tool-arg include_symbols=true
    
    echo Testing network_ping tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name network_ping --tool-arg hostname=google.com --tool-arg count=2
    
    echo Testing fortune_teller tool...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method tools/call --tool-name fortune_teller --tool-arg name="TestUser" --tool-arg category=general
    
    echo Testing current time resource...
    npx @modelcontextprotocol/inspector --cli "%EXE_PATH%" --method resources/read --resource-uri "time://current"
    
    echo ✓ All predefined tests completed
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
    echo You can test with:
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
    echo   # Test HTTP endpoint (another terminal)
    echo   npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/list
    echo   npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/call --tool-name echo --tool-arg message="HTTP test"
    goto :eof