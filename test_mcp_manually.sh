#!/bin/bash
# Manual MCP test script

EXE_PATH="/mnt/d/_dev/DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"

echo "Testing MCP Server manually..."
echo "================================"

# Create a temporary input file with proper MCP protocol
cat > /tmp/mcp_test_input.json << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","method":"initialized","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF

echo "Sending MCP messages to server..."
echo "Input messages:"
cat /tmp/mcp_test_input.json
echo
echo "Server responses:"
cat /tmp/mcp_test_input.json | "$EXE_PATH"

echo
echo "Test completed."