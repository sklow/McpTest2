#!/bin/bash
# MCP Inspector HTTP transport test script for DotNetFrameworkMcpServer
# This script tests the server using HTTP transport with MCP Inspector

set -e

echo "================================================"
echo "  MCP Inspector HTTP Transport Test (WSL/Linux)"
echo "================================================"
echo

# Configuration
EXE_PATH="DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"
SERVER_HOST="localhost"
SERVER_PORT="41114"
SERVER_PATH="/mcp"
SERVER_URL="http://${SERVER_HOST}:${SERVER_PORT}${SERVER_PATH}"

# Check if the executable exists
if [ ! -f "$EXE_PATH" ]; then
    echo "Error: $EXE_PATH not found!"
    echo "Please build the project first using:"
    echo "  ./build-debug.sh"
    echo "  or"
    echo "  dotnet build DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln -c Debug"
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
echo "Checking MCP Inspector availability..."
if ! npx @modelcontextprotocol/inspector --help &> /dev/null; then
    echo "Warning: MCP Inspector may not be available or installed."
    echo "Will attempt to run anyway..."
fi

# Function to start the server
start_server() {
    echo "Starting DotNetFrameworkMcpServer with HTTP transport..."
    echo "Server URL: $SERVER_URL"
    echo "Host: $SERVER_HOST"
    echo "Port: $SERVER_PORT"
    echo "Path: $SERVER_PATH"
    echo
    
    # Start the server in background
    "$EXE_PATH" --transport http --host "$SERVER_HOST" --port "$SERVER_PORT" --path "$SERVER_PATH" &
    SERVER_PID=$!
    
    echo "Server started with PID: $SERVER_PID"
    echo "Waiting for server to initialize..."
    sleep 3
    
    # Check if server is running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "Error: Server failed to start!"
        exit 1
    fi
    
    # Test server availability
    echo "Testing server availability..."
    if curl -s -f --max-time 5 "$SERVER_URL" > /dev/null 2>&1; then
        echo "✅ Server is responding at $SERVER_URL"
    else
        echo "⚠️  Server may not be fully ready yet (this is normal)"
    fi
    echo
}

# Function to stop the server
stop_server() {
    if [ ! -z "$SERVER_PID" ]; then
        echo
        echo "Stopping server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        echo "Server stopped."
    fi
}

# Trap to ensure server cleanup
trap stop_server EXIT INT TERM

# Start the server
start_server

echo "========================================"
echo "  Starting MCP Inspector"
echo "========================================"
echo
echo "The MCP Inspector will open in your default web browser."
echo "Server URL to test: $SERVER_URL"
echo
echo "To test the HTTP transport in the Inspector:"
echo "1. Select 'Streamable HTTP' transport"
echo "2. Enter Server URL: $SERVER_URL"
echo "3. Click 'Connect'"
echo "4. Test tools/list method"
echo
echo "Press Ctrl+C to stop both the server and inspector."
echo
echo "Starting MCP Inspector..."

# Start MCP Inspector
# The inspector will open a web interface where you can manually configure the HTTP transport
npx @modelcontextprotocol/inspector

echo
echo "MCP Inspector session ended."