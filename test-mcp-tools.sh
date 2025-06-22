#!/bin/bash
# MCP Tool Testing Script for DotNetFrameworkMcpServer
# This script provides comprehensive testing functionality for MCP tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXE_PATH="$SCRIPT_DIR/DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"

echo "========================================"
echo "  MCP Tool Testing Script"
echo "========================================"
echo

# Function to check prerequisites
check_prerequisites() {
    # Check if the executable exists
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
}

# Function to test server connectivity
test_connectivity() {
    echo "Testing server connectivity..."
    npx @modelcontextprotocol/inspector --cli "$EXE_PATH" --method initialize --timeout 10
    echo "✓ Server connectivity test passed"
    echo
}

# Function to list all available tools
list_tools() {
    echo "=== Available Tools ==="
    npx @modelcontextprotocol/inspector --cli "$EXE_PATH" --method tools/list
    echo
}

# Function to list all available resources
list_resources() {
    echo "=== Available Resources ==="
    npx @modelcontextprotocol/inspector --cli "$EXE_PATH" --method resources/list
    echo
}

# Function to call a specific tool with arguments
call_tool() {
    local tool_name="$1"
    shift
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --arg)
                args+=("--tool-arg" "$2")
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    echo "=== Calling Tool: $tool_name ==="
    npx @modelcontextprotocol/inspector --cli "$EXE_PATH" --method tools/call --tool-name "$tool_name" "${args[@]}"
    echo
}

# Function to read a resource
read_resource() {
    local resource_uri="$1"
    echo "=== Reading Resource: $resource_uri ==="
    npx @modelcontextprotocol/inspector --cli "$EXE_PATH" --method resources/read --resource-uri "$resource_uri"
    echo
}

# Function to run predefined tests
run_tests() {
    echo "=== Running Predefined Tests ==="
    
    # Test echo tool
    echo "Testing echo tool..."
    call_tool echo --arg message="Hello from MCP test!"
    
    # Test system_info tool
    echo "Testing system_info tool..."
    call_tool system_info --arg info_type=os
    
    # Test misezan tool
    echo "Testing misezan tool..."
    call_tool misezan --arg num1=5 --arg num2=3
    
    # Test delay_response tool
    echo "Testing delay_response tool..."
    call_tool delay_response --arg seconds=2 --arg message="Delayed response test"
    
    # Test password_generator tool
    echo "Testing password_generator tool..."
    call_tool password_generator --arg length=16 --arg include_symbols=true
    
    # Test network_ping tool
    echo "Testing network_ping tool..."
    call_tool network_ping --arg hostname=google.com --arg count=2
    
    # Test fortune_teller tool
    echo "Testing fortune_teller tool..."
    call_tool fortune_teller --arg name="TestUser" --arg category=general
    
    # Test current time resource
    echo "Testing current time resource..."
    read_resource "time://current"
    
    echo "✓ All predefined tests completed"
}

# Function to start HTTP server for testing
start_http_server() {
    echo "Starting HTTP/SSE server for testing..."
    echo "Server will be available at: http://localhost:41114"
    echo "Press Ctrl+C to stop the server"
    echo
    
    # Start server in HTTP mode
    "$EXE_PATH" http
}

# Function to test HTTP/SSE endpoint
test_http_endpoint() {
    echo "=== Testing HTTP/SSE Endpoint ==="
    echo "Make sure the server is running in HTTP mode first!"
    echo "You can test with:"
    echo "  npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/list"
    echo
}

# Function to show usage
show_usage() {
    cat << EOF
MCP Tool Testing Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  check               Check prerequisites
  connectivity        Test server connectivity
  list-tools          List all available tools
  list-resources      List all available resources
  call-tool TOOL      Call a specific tool with arguments
  read-resource URI   Read a specific resource
  test-all           Run all predefined tests
  start-http         Start HTTP/SSE server
  test-http          Show HTTP/SSE testing instructions
  help               Show this help message

Tool Call Examples:
  $0 call-tool echo --arg message="Hello World"
  $0 call-tool system_info --arg info_type=memory
  $0 call-tool misezan --arg num1=6 --arg num2=9
  $0 call-tool delay_response --arg seconds=3 --arg message="Test"
  $0 call-tool password_generator --arg length=20 --arg include_symbols=false
  $0 call-tool network_ping --arg hostname=example.com --arg count=3
  $0 call-tool fortune_teller --arg name="Alice" --arg category=love
  $0 call-tool file_operations --arg operation=create --arg filename=test.txt --arg content="Test content"
  $0 call-tool encryption --arg operation=encrypt --arg text="secret" --arg password="mypass"
  $0 call-tool qr_generator --arg text="https://example.com" --arg size=25
  $0 call-tool memory_monitor --arg duration=5

Resource Examples:
  $0 read-resource "time://current"

HTTP/SSE Testing:
  # Start server in HTTP mode (separate terminal)
  $0 start-http
  
  # Test HTTP endpoint (another terminal)
  npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/list
  npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/call --tool-name echo --tool-arg message="HTTP test"
EOF
}

# Main script logic
case "${1:-help}" in
    check)
        check_prerequisites
        ;;
    connectivity)
        check_prerequisites
        test_connectivity
        ;;
    list-tools)
        check_prerequisites
        list_tools
        ;;
    list-resources)
        check_prerequisites
        list_resources
        ;;
    call-tool)
        if [ $# -lt 2 ]; then
            echo "Error: Tool name required"
            echo "Usage: $0 call-tool TOOL_NAME [--arg key=value ...]"
            exit 1
        fi
        check_prerequisites
        call_tool "$@"
        ;;
    read-resource)
        if [ $# -lt 2 ]; then
            echo "Error: Resource URI required"
            echo "Usage: $0 read-resource RESOURCE_URI"
            exit 1
        fi
        check_prerequisites
        read_resource "$2"
        ;;
    test-all)
        check_prerequisites
        run_tests
        ;;
    start-http)
        check_prerequisites
        start_http_server
        ;;
    test-http)
        test_http_endpoint
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac