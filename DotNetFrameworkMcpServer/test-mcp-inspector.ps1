# MCP Inspector test script for DotNetFrameworkMcpServer
# This script runs the MCP Inspector with the built DotNetFrameworkMcpServer.exe

param(
    [string]$Configuration = "Release",
    [switch]$Debug,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
MCP Inspector Test Script for DotNetFrameworkMcpServer

Usage:
  .\test-mcp-inspector.ps1 [-Configuration <Release|Debug>] [-Debug] [-Help]

Parameters:
  -Configuration    Build configuration (Release or Debug). Default: Release
  -Debug           Use Debug build configuration
  -Help            Show this help message

Examples:
  .\test-mcp-inspector.ps1                    # Use Release build
  .\test-mcp-inspector.ps1 -Debug            # Use Debug build
  .\test-mcp-inspector.ps1 -Configuration Debug  # Same as above
"@
    return
}

if ($Debug) {
    $Configuration = "Debug"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MCP Inspector Test Script (PowerShell)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host

# Check if the executable exists
$ExePath = "DotNetFrameworkMcpServer\bin\$Configuration\DotNetFrameworkMcpServer.exe"
if (-not (Test-Path $ExePath)) {
    Write-Host "Error: $ExePath not found!" -ForegroundColor Red
    Write-Host "Please build the project first using:" -ForegroundColor Yellow
    Write-Host "  dotnet build DotNetFrameworkMcpServer.sln -c $Configuration" -ForegroundColor Yellow
    Write-Host
    Read-Host "Press Enter to exit"
    return
}

# Check if npm is available
try {
    $null = Get-Command npm -ErrorAction Stop
} catch {
    Write-Host "Error: npm is not installed!" -ForegroundColor Red
    Write-Host "Please install Node.js and npm first." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    return
}

# Check if MCP Inspector is available
try {
    $null = npx @modelcontextprotocol/inspector --version 2>$null
} catch {
    Write-Host "MCP Inspector not found. Installing..." -ForegroundColor Yellow
    try {
        npm install -g @modelcontextprotocol/inspector
        if ($LASTEXITCODE -ne 0) {
            throw "Installation failed"
        }
    } catch {
        Write-Host "Failed to install MCP Inspector!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        return
    }
}

Write-Host "Starting MCP Inspector with DotNetFrameworkMcpServer..." -ForegroundColor Green
Write-Host "Executable: $ExePath" -ForegroundColor Gray
Write-Host "Mode: STDIO (default)" -ForegroundColor Gray
Write-Host
Write-Host "The inspector will open in your default web browser." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the inspector." -ForegroundColor Yellow
Write-Host

try {
    # Run MCP Inspector with the executable
    npx @modelcontextprotocol/inspector --cli "$ExePath"
} catch {
    Write-Host "Error running MCP Inspector: $_" -ForegroundColor Red
} finally {
    Write-Host
    Write-Host "MCP Inspector session ended." -ForegroundColor Green
}

if ($PSCmdlet.MyInvocation.InvocationName -ne '&') {
    Read-Host "Press Enter to exit"
}