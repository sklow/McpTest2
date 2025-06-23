#!/bin/bash

# Build script for .NET Framework MCP Server
# Uses the dotnet CLI at /home/hosin/bin/dotnet

DOTNET_PATH="/home/hosin/bin/dotnet"
SOLUTION_PATH="DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln"

echo "Building .NET Framework MCP Server..."

# Build Release configuration
echo "Building Release configuration..."
$DOTNET_PATH build $SOLUTION_PATH -c Release

if [ $? -eq 0 ]; then
    echo "✅ Release build successful!"
    echo "Executable: DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Release/DotNetFrameworkMcpServer.exe"
else
    echo "❌ Release build failed!"
    exit 1
fi