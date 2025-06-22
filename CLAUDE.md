# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a Model Context Protocol (MCP) server implementation in .NET Framework 4.8.1 that enables Claude Desktop to communicate with external tools and resources through JSON-RPC 2.0 over STDIO transport.

**Key Architecture Components:**
- **Program.cs:24** - Entry point that initializes StdioServer
- **McpServer.cs** - Core MCP protocol implementation with 31 built-in tools
- **StdioServer.cs** - STDIO transport layer for Claude Desktop integration
- **JsonRpcMessage.cs** - JSON-RPC message definitions and error codes

**Data Flow:**
STDIO → JSON-RPC parsing → MCP protocol handling → Tool/Resource execution

## Project Structure

**Critical Path Information:**
- **Solution**: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln`
- **Project**: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.csproj`
- **Source**: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/*.cs`
- **Release Build**: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Release/DotNetFrameworkMcpServer.exe`
- **Debug Build**: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe`

**Important:** This project has a three-level nested folder structure that can cause path confusion.

## Build Commands

### Prerequisites
- .NET Framework 4.8.1 or later
- .NET SDK 6.0 or later (for building)

### Build
```bash
# Build Release (recommended)
dotnet build DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln -c Release

# Build Debug
dotnet build DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln -c Debug

# Quick Debug build using batch script (Windows)
build-debug.bat

# Clean
dotnet clean DotNetFrameworkMcpServer/DotNetFrameworkMcpServer.sln
```

### Run
```bash
# Run Release build
DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Release/DotNetFrameworkMcpServer.exe

# Run Debug build  
DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe
```

### Build Dependencies
If you encounter build errors related to missing references, ensure the following dependencies are properly configured:

**Required Assembly References (in .csproj)**:
- `System.Drawing` - Required for image processing tools
- `System.Management` - Required for system information tools  
- `System.Net.Http` - Required for web-related operations
- `log4net` - Required for logging functionality

**Required NuGet Packages (in packages.config)**:
- `Newtonsoft.Json 13.0.3` - JSON serialization
- `log4net 2.0.17` - Logging framework

**Common Build Fixes**:
- Add `<Reference Include="System.Drawing"/>` if you see CS0234 errors about System.Drawing.Imaging
- Ensure correct log4net HintPath: `<HintPath>..\packages\log4net.2.0.17\lib\net45\log4net.dll</HintPath>`
- Run `nuget restore` if packages are missing from the packages folder
- Ensure all .cs files are included in `<Compile Include="..."/>` sections

**Log4net Configuration**:
- log4net is used for logging in StdioServer to avoid interfering with STDIO communication
- Configuration file: `log4net.config` (should be in project root)
- Console output is avoided in STDIO mode to prevent interference with JSON-RPC communication


## MCP Tools and Resources

### Tool Registration
Tools are registered in `McpServer.cs:257` within the `InitializeDefaultToolsAndResources()` method. The server includes **31 built-in tools** that provide capabilities beyond typical AI functionality:

**Tool Categories:**
- **System Access**: file_operations, system_info, memory_monitor, network_ping
- **Data Processing**: json_manipulator, csv_processor, sql_simulator, statistics_analyzer
- **Security**: encryption, password_generator
- **Data Structures**: dictionary_manager, array_operations, graph_operations
- **Analysis**: code_analyzer, log_analyzer, text_analyzer, web_analyzer
- **Utilities**: delay_response, qr_generator, math_calculator, task_scheduler

### Resources
The server provides 2 resources:
1. **time://current** - Current system date and time (text/plain)
2. **datastore://summary** - Summary of stored data structures (application/json)

### Unique Capabilities
These tools provide system-level functionality including:
- Physical file system and process access
- Real-time network operations and monitoring
- Cryptographic operations and secure random generation
- Persistent in-memory data structures across sessions

## Adding Custom Tools

Tools are registered in McpServer.cs:257. Example pattern:

```csharp
var newTool = new McpTool
{
    Name = "tool_name",
    Description = "Tool description",
    InputSchema = new { /* JSON schema */ }
};
newTool.ExecuteFunc = async (args) => { /* implementation */ };
_tools[newTool.Name] = newTool;
```

## Adding Custom Resources

Resources are registered in McpServer.cs InitializeDefaultToolsAndResources(). Example pattern:

```csharp
var newResource = new McpResource
{
    Uri = "scheme://resource",
    Name = "Resource Name", 
    Description = "Resource description",
    MimeType = "text/plain"
};
newResource.ReadFunc = async () => { /* implementation */ };
_resources[newResource.Uri] = newResource;
```

## Testing

### Test Scripts
All test scripts are now located in the root directory:

**Primary Test Scripts:**
- **quick-test.bat** - Comprehensive functionality test (requires Debug build)
- **test-mcp-simple.bat [command]** - Targeted testing (commands: list-tools, list-resources, test-echo, help)
- **test-mcp-inspector.{bat,sh,ps1}** - MCP Inspector integration testing
- **test-mcp-tools.{bat,sh}** - Comprehensive tool testing with detailed options

**Additional Test Scripts:**
- **test-mcp-{en,jp}.{bat,ps1}** - Language-specific testing variants
- **test_mcp_manually.sh** - Manual testing script

### Testing Prerequisites
- Debug build: `DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Debug/DotNetFrameworkMcpServer.exe`
- For MCP Inspector: Node.js/npm with `@modelcontextprotocol/inspector`

## Key Dependencies and Configuration

**Dependencies:**
- Newtonsoft.Json 13.0.3 (JSON serialization)
- log4net 2.0.17 (logging framework)
- System.Drawing, System.Management, System.Net.Http (framework references)

**Configuration:**
- Default transport: STDIO only
- Character encoding: UTF-8 without BOM
- Logging: log4net.config (avoids STDIO interference)
- Data persistence: In-memory structures across tool calls

## Claude Desktop Setup

Configure Claude Desktop to use this MCP server by adding to your `claude_desktop_config.json`:

**Windows:**
```json
{
  "mcpServers": {
    "dotnet-framework-mcp": {
      "command": "C:\\path\\to\\DotNetFrameworkMcpServer\\DotNetFrameworkMcpServer\\bin\\Release\\DotNetFrameworkMcpServer.exe"
    }
  }
}
```

**Linux/WSL:**
```json
{
  "mcpServers": {
    "dotnet-framework-mcp": {
      "command": "/path/to/DotNetFrameworkMcpServer/DotNetFrameworkMcpServer/bin/Release/DotNetFrameworkMcpServer.exe"
    }
  }
}
```

## Transport Implementation

**Current:** STDIO transport only (Program.cs:24 initializes StdioServer)

This server is designed specifically for STDIO transport to integrate with Claude Desktop.

## Development Notes

- This server uses UTF-8 encoding without BOM to prevent JSON parsing issues
- Console output is avoided in STDIO mode to prevent JSON-RPC interference  
- log4net is used for logging to avoid STDIO conflicts
- Data structures (dictionaries, arrays, tables, graphs) persist in memory across tool calls

## Important Reminders

- Always build Debug configuration before running tests (test scripts require Debug build)
- Avoid console output in STDIO mode to prevent JSON-RPC interference
- Use log4net for debugging instead of Console.WriteLine when troubleshooting STDIO issues

## Important Implementation Details

**Character Encoding**: UTF-8 without BOM is critical for proper JSON-RPC communication. The STDIO transport uses `new UTF8Encoding(false)` to prevent BOM interference.

**Error Handling**: All console output in STDIO mode must go to stderr (`Console.Error.WriteLine`) to avoid interfering with JSON-RPC communication on stdout.

**MCP Protocol Methods**: The server implements these exact method names:
- `initialize` - Initialize the server with client capabilities
- `initialized` - Notification that initialization is complete (no ID, notification only)
- `tools/list`, `tools/call` - Tool operations
- `resources/list`, `resources/read` - Resource operations

Note: Use `initialized` not `notifications/initialized` - this was a common error in early test scripts.

**Tool Architecture**: Tools are implemented as `McpTool` objects with:
- `Name`: Tool identifier
- `Description`: Human-readable description  
- `InputSchema`: JSON schema for parameter validation
- `ExecuteFunc`: Async function that processes arguments and returns results

**Resource Architecture**: Resources use URI-based addressing with `McpResource` objects containing:
- `Uri`: Resource identifier (scheme://path format)
- `Name`: Display name
- `Description`: Human-readable description
- `MimeType`: Content type
- `ReadFunc`: Async function that returns resource content

**Data Persistence**: The server maintains in-memory data structures across tool calls:
- `_dictionaries`: Key-value stores by name
- `_arrays`: Lists by name  
- `_tables`: Table structures by name
- `_graphs`: Graph adjacency lists by name

This enables stateful operations where tools can store and retrieve data across multiple invocations within the same server session.