@echo off
REM HTTP MCP Server Test Script
REM Tests the HTTP transport functionality

chcp 65001 >nul
setlocal enabledelayedexpansion

set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe"
set "HOST=localhost"
set "PORT=8080"
set "ENDPOINT=http://%HOST%:%PORT%/mcp"

echo ========================================
echo  HTTP MCP Server Test
echo ========================================
echo.

if not exist "%EXE_PATH%" (
    echo Error: %EXE_PATH% not found!
    echo Please build the project first using: build-debug.bat
    pause
    exit /b 1
)

echo Starting HTTP MCP Server on %ENDPOINT%...
echo Press Ctrl+C to stop the server
echo.

REM Start the server in HTTP mode
start "MCP HTTP Server" "%EXE_PATH%" --transport http --host %HOST% --port %PORT%

REM Wait a moment for server to start
timeout /t 3 /nobreak >nul

echo Testing HTTP MCP Server functionality...
echo.

REM Test using PowerShell to make HTTP requests
powershell -Command "
$ErrorActionPreference = 'Stop'
try {
    # Test 1: Initialize request
    Write-Host 'Test 1: Initialize' -ForegroundColor Green
    $initRequest = @{
        jsonrpc = '2.0'
        id = 1
        method = 'initialize'
        params = @{
            protocolVersion = '2024-11-05'
            capabilities = @{}
            clientInfo = @{
                name = 'test-client'
                version = '1.0'
            }
        }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }

    $response = Invoke-RestMethod -Uri '%ENDPOINT%' -Method POST -Body $initRequest -Headers $headers -TimeoutSec 10
    Write-Host 'Initialize Response:' $response
    Write-Host ''

    # Test 2: List tools
    Write-Host 'Test 2: List Tools' -ForegroundColor Green
    $toolsRequest = @{
        jsonrpc = '2.0'
        id = 2
        method = 'tools/list'
        params = @{}
    } | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Uri '%ENDPOINT%' -Method POST -Body $toolsRequest -Headers $headers -TimeoutSec 10
    if ($response.result -and $response.result.tools) {
        Write-Host 'Found' $response.result.tools.Count 'tools:'
        foreach ($tool in $response.result.tools) {
            Write-Host '  -' $tool.name
        }
    }
    Write-Host ''

    # Test 3: Echo tool test
    Write-Host 'Test 3: Echo Tool' -ForegroundColor Green
    $echoRequest = @{
        jsonrpc = '2.0'
        id = 3
        method = 'tools/call'
        params = @{
            name = 'echo'
            arguments = @{
                message = 'Hello HTTP MCP Server!'
            }
        }
    } | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Uri '%ENDPOINT%' -Method POST -Body $echoRequest -Headers $headers -TimeoutSec 10
    if ($response.result -and $response.result.content) {
        Write-Host 'Echo Result:' $response.result.content[0].text
    }
    Write-Host ''

    # Test 4: List resources
    Write-Host 'Test 4: List Resources' -ForegroundColor Green
    $resourcesRequest = @{
        jsonrpc = '2.0'
        id = 4
        method = 'resources/list'
        params = @{}
    } | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Uri '%ENDPOINT%' -Method POST -Body $resourcesRequest -Headers $headers -TimeoutSec 10
    if ($response.result -and $response.result.resources) {
        Write-Host 'Found' $response.result.resources.Count 'resources:'
        foreach ($resource in $response.result.resources) {
            Write-Host '  -' $resource.uri ':' $resource.name
        }
    }
    Write-Host ''

    Write-Host 'All HTTP tests completed successfully!' -ForegroundColor Green

} catch {
    Write-Host 'HTTP Test Error:' $_.Exception.Message -ForegroundColor Red
    Write-Host 'Make sure the HTTP server is running with: %EXE_PATH% --transport http' -ForegroundColor Yellow
}
"

echo.
echo Test completed. Press any key to stop the server...
pause >nul

REM Try to stop the server gracefully
taskkill /F /FI "WINDOWTITLE eq MCP HTTP Server*" >nul 2>&1