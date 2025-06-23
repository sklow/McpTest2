#!/bin/bash
# Direct HTTP test script for DotNetFrameworkMcpServer
# This script tests HTTP transport directly using curl

set -e

echo "=============================================="
echo "  Direct HTTP Transport Test (WSL/Linux)"
echo "=============================================="
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
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed!"
    echo "Please install curl first."
    exit 1
fi

# Function to start the server
start_server() {
    echo "Starting DotNetFrameworkMcpServer with HTTP transport..."
    echo "Server URL: $SERVER_URL"
    
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
    
    echo "✅ Server is running"
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

# Function to test HTTP endpoint
test_http_endpoint() {
    local method="$1"
    local description="$2"
    
    echo "Testing: $description"
    echo "Method: $method"
    
    local request_body=""
    case "$method" in
        "tools/list")
            request_body='{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
            ;;
        "resources/list")
            request_body='{"jsonrpc":"2.0","id":2,"method":"resources/list"}'
            ;;
        "initialize")
            request_body='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{"roots":{"listChanged":false},"sampling":{}}}}'
            ;;
    esac
    
    echo "Request: $request_body"
    echo
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$request_body" \
        "$SERVER_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$response" ]; then
        echo "✅ Response received:"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        echo "❌ Failed to get response"
    fi
    echo
    echo "----------------------------------------"
    echo
}

# Trap to ensure server cleanup
trap stop_server EXIT INT TERM

# Start the server
start_server

echo "========================================"
echo "  Testing HTTP Endpoints"
echo "========================================"
echo

# Test basic connectivity
echo "Testing basic connectivity..."
if curl -s -f --max-time 5 "$SERVER_URL" > /dev/null 2>&1; then
    echo "✅ Server is responding"
else
    echo "⚠️  Basic connectivity test failed, but proceeding with MCP tests"
fi
echo

# Test MCP methods
test_http_endpoint "initialize" "Server initialization"
test_http_endpoint "tools/list" "List available tools"
test_http_endpoint "resources/list" "List available resources"

echo "========================================"
echo "  Test Summary"
echo "========================================"
echo
echo "Server URL tested: $SERVER_URL"
echo
echo "For interactive testing with MCP Inspector:"
echo "1. Keep this server running"
echo "2. Run: npx @modelcontextprotocol/inspector"
echo "3. Select 'Streamable HTTP' transport"
echo "4. Enter Server URL: $SERVER_URL"
echo
echo "Press Ctrl+C to stop the server."
echo

# Keep server running until user stops it
read -p "Press Enter to stop the server..."