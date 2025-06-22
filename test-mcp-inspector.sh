#!/bin/bash
# MCP Inspector test script for DotNetFrameworkMcpServer
# This script runs the MCP Inspector with the built DotNetFrameworkMcpServer.exe

set -e

echo "========================================"
echo "  MCP Inspector Test Script (WSL/Linux)"
echo "========================================"
echo

# Check if the executable exists
EXE_PATH="DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"
if [ ! -f "$EXE_PATH" ]; then
    echo "Error: $EXE_PATH not found!"
    echo "Please build the project first using:"
    echo "  dotnet build DotNetFrameworkMcpServer.sln -c Debug"
    echo
    exit 1
fi

# Check if node/npm is available
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed!"
    echo "Please install Node.js and npm first."
    exit 1
fi

# Check if MCP Inspector is available
if ! npx @modelcontextprotocol/inspector --version &> /dev/null; then
    echo "MCP Inspector not found. Installing..."
    npm install -g @modelcontextprotocol/inspector
fi

echo "Starting MCP Inspector with DotNetFrameworkMcpServer..."
echo "Executable: $EXE_PATH"
echo "Mode: STDIO (default)"
echo
echo "The inspector will open in your default web browser."
echo "Press Ctrl+C to stop the inspector."
echo

# Run MCP Inspector with the executable
npx @modelcontextprotocol/inspector --cli "$EXE_PATH"

echo
echo "MCP Inspector session ended."