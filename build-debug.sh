#!/bin/bash

# Debug build script for .NET Framework MCP Server
# Uses the dotnet CLI at /home/hosin/bin/dotnet

DOTNET_PATH="/home/hosin/bin/dotnet"
SOLUTION_PATH="DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln"

echo "Building .NET Framework MCP Server (Debug)..."

# Build Debug configuration
echo "Building Debug configuration..."
$DOTNET_PATH build $SOLUTION_PATH -c Debug

if [ $? -eq 0 ]; then
    echo "✅ Debug build successful!"
    echo "Executable: DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe"
else
    echo "❌ Debug build failed!"
    exit 1
fi