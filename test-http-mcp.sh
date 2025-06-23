#!/bin/bash

# HTTP MCP Server Test Script (Linux/WSL)
# Tests the HTTP transport functionality

EXE_PATH="DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"
HOST="localhost"
PORT=8080
ENDPOINT="http://$HOST:$PORT/mcp"

echo "========================================"
echo " HTTP MCP Server Test"
echo "========================================"
echo

if [ ! -f "$EXE_PATH" ]; then
    echo "Error: $EXE_PATH not found!"
    echo "Please build the project first using: ./build-debug.sh"
    exit 1
fi

echo "Starting HTTP MCP Server on $ENDPOINT..."
echo "Press Ctrl+C to stop the server"
echo

# Start the server in HTTP mode in background
"$EXE_PATH" --transport http --host "$HOST" --port "$PORT" &
SERVER_PID=$!

# Function to cleanup server on exit
cleanup() {
    echo
    echo "Stopping HTTP MCP Server..."
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    echo "Server stopped."
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Wait a moment for server to start
sleep 3

echo "Testing HTTP MCP Server functionality..."
echo

# Test 1: Initialize request
echo "Test 1: Initialize"
echo "=================="
INIT_REQUEST='{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {
            "name": "test-client",
            "version": "1.0"
        }
    }
}'

RESPONSE=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$INIT_REQUEST" \
    --connect-timeout 10 \
    --max-time 10)

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "Initialize Response: $RESPONSE"
    echo
else
    echo "Failed to connect to HTTP server. Make sure it's running."
    exit 1
fi

# Test 2: List tools
echo "Test 2: List Tools"
echo "=================="
TOOLS_REQUEST='{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
}'

RESPONSE=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$TOOLS_REQUEST")

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "Tools found:"
    echo "$RESPONSE" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | sed 's/^/  - /'
    echo
fi

# Test 3: Echo tool test
echo "Test 3: Echo Tool"
echo "================="
ECHO_REQUEST='{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
        "name": "echo",
        "arguments": {
            "message": "Hello HTTP MCP Server!"
        }
    }
}'

RESPONSE=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$ECHO_REQUEST")

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "Echo Result:"
    echo "$RESPONSE" | grep -o '"text":"[^"]*"' | sed 's/"text":"//g' | sed 's/"//g'
    echo
fi

# Test 4: List resources
echo "Test 4: List Resources"
echo "====================="
RESOURCES_REQUEST='{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "resources/list",
    "params": {}
}'

RESPONSE=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$RESOURCES_REQUEST")

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo "Resources found:"
    echo "$RESPONSE" | grep -o '"uri":"[^"]*"' | sed 's/"uri":"//g' | sed 's/"//g' | sed 's/^/  - /'
    echo
fi

echo "All HTTP tests completed successfully!"
echo
echo "Press Enter to stop the server..."
read -r