using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;
using System.Text;
using System.Net.NetworkInformation;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Linq;
using System.Diagnostics;
using System.Net;
using System.Drawing;
using System.Drawing.Imaging;
using System.Management;
using log4net;

namespace DotNetFrameworkMcpServer
{
    public class McpServer
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(McpServer));
        
        private bool _initialized = false;
        private readonly Dictionary<string, McpTool> _tools;
        private readonly Dictionary<string, McpResource> _resources;
        
        // Data storage for persistent operations
        private readonly Dictionary<string, Dictionary<string, object>> _dictionaries;
        private readonly Dictionary<string, List<object>> _arrays;
        private readonly Dictionary<string, List<Dictionary<string, object>>> _tables;
        private readonly Dictionary<string, Dictionary<string, List<string>>> _graphs;
        private readonly Random _random;

        public McpServer()
        {
            _tools = new Dictionary<string, McpTool>();
            _resources = new Dictionary<string, McpResource>();
            _dictionaries = new Dictionary<string, Dictionary<string, object>>();
            _arrays = new Dictionary<string, List<object>>();
            _tables = new Dictionary<string, List<Dictionary<string, object>>>();
            _graphs = new Dictionary<string, Dictionary<string, List<string>>>();
            _random = new Random();
            InitializeDefaultToolsAndResources();
        }

        public async Task<string> HandleMessageAsync(string message)
        {
            try
            {
                var request = JsonConvert.DeserializeObject<JsonRpcRequest>(message);
                
                if (request == null || request.JsonRpc != "2.0")
                {
                    return CreateErrorResponse(null, JsonRpcErrorCodes.InvalidRequest, "Invalid JSON-RPC request");
                }

                return await ProcessRequestAsync(request);
            }
            catch (JsonException)
            {
                return CreateErrorResponse(null, JsonRpcErrorCodes.ParseError, "Parse error");
            }
            catch (Exception ex)
            {
                Log.Error($"Error handling message: {ex.Message}", ex);
                return CreateErrorResponse(null, JsonRpcErrorCodes.InternalError, "Internal error");
            }
        }

        private async Task<string> ProcessRequestAsync(JsonRpcRequest request)
        {
            switch (request.Method)
            {
                case "initialize":
                    return await HandleInitializeAsync(request);
                
                case "initialized":
                    return HandleInitialized(request);
                
                case "tools/list":
                    return HandleToolsList(request);
                
                case "tools/call":
                    return await HandleToolsCallAsync(request);
                
                case "resources/list":
                    return HandleResourcesList(request);
                
                case "resources/read":
                    return await HandleResourcesReadAsync(request);
                
                default:
                    return CreateErrorResponse(request.Id, JsonRpcErrorCodes.MethodNotFound, $"Method not found: {request.Method}");
            }
        }

        private Task<string> HandleInitializeAsync(JsonRpcRequest request)
        {
            var result = new
            {
                protocolVersion = "2024-11-05",
                capabilities = new
                {
                    tools = new { },
                    resources = new { }
                },
                serverInfo = new
                {
                    name = "DotNetFrameworkMcpServer",
                    version = "1.0.0"
                }
            };

            return Task.FromResult(CreateSuccessResponse(request.Id, result));
        }

        private string HandleInitialized(JsonRpcRequest request)
        {
            _initialized = true;
            Log.Info("MCP Server initialized successfully");
            return null;
        }

        private string HandleToolsList(JsonRpcRequest request)
        {
            if (!_initialized)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidRequest, "Server not initialized");
            }

            var tools = new List<object>();
            foreach (var tool in _tools.Values)
            {
                tools.Add(new
                {
                    name = tool.Name,
                    description = tool.Description,
                    inputSchema = tool.InputSchema
                });
            }

            var result = new { tools = tools };
            return CreateSuccessResponse(request.Id, result);
        }

        private async Task<string> HandleToolsCallAsync(JsonRpcRequest request)
        {
            if (!_initialized)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidRequest, "Server not initialized");
            }

            var toolName = request.Params?["name"]?.ToString();
            var arguments = request.Params?["arguments"] as JObject;

            if (string.IsNullOrEmpty(toolName))
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidParams, "Tool name is required");
            }

            if (!_tools.ContainsKey(toolName))
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidParams, $"Tool not found: {toolName}");
            }

            try
            {
                var tool = _tools[toolName];
                var result = await tool.ExecuteAsync(arguments);
                
                var response = new
                {
                    content = new[]
                    {
                        new
                        {
                            type = "text",
                            text = result
                        }
                    }
                };

                return CreateSuccessResponse(request.Id, response);
            }
            catch (Exception ex)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InternalError, $"Tool execution failed: {ex.Message}");
            }
        }

        private string HandleResourcesList(JsonRpcRequest request)
        {
            if (!_initialized)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidRequest, "Server not initialized");
            }

            var resources = new List<object>();
            foreach (var resource in _resources.Values)
            {
                resources.Add(new
                {
                    uri = resource.Uri,
                    name = resource.Name,
                    description = resource.Description,
                    mimeType = resource.MimeType
                });
            }

            var result = new { resources = resources };
            return CreateSuccessResponse(request.Id, result);
        }

        private async Task<string> HandleResourcesReadAsync(JsonRpcRequest request)
        {
            if (!_initialized)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidRequest, "Server not initialized");
            }

            var uri = request.Params?["uri"]?.ToString();
            if (string.IsNullOrEmpty(uri))
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidParams, "Resource URI is required");
            }

            if (!_resources.ContainsKey(uri))
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InvalidParams, $"Resource not found: {uri}");
            }

            try
            {
                var resource = _resources[uri];
                var content = await resource.ReadAsync();
                
                var response = new
                {
                    contents = new[]
                    {
                        new
                        {
                            uri = resource.Uri,
                            mimeType = resource.MimeType,
                            text = content
                        }
                    }
                };

                return CreateSuccessResponse(request.Id, response);
            }
            catch (Exception ex)
            {
                return CreateErrorResponse(request.Id, JsonRpcErrorCodes.InternalError, $"Resource read failed: {ex.Message}");
            }
        }

        private void InitializeDefaultToolsAndResources()
        {
            // Core Tools (11 tools)
            InitializeCoreTools();
            
            // Data Structure Tools (10 tools)
            InitializeDataStructureTools();
            
            // Advanced Tools (10 tools)
            InitializeAdvancedTools();
            
            // Resources
            InitializeResources();
        }

        private void InitializeCoreTools()
        {
            // 1. Echo Tool
            var echoTool = new McpTool
            {
                Name = "echo",
                Description = "Echo input messages (test tool)",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        message = new { type = "string", description = "Message to echo" }
                    },
                    required = new[] { "message" }
                }
            };
            echoTool.ExecuteFunc = (args) =>
            {
                var message = args?["message"]?.ToString() ?? "No message provided";
                return Task.FromResult($"Echo: {message}");
            };
            _tools[echoTool.Name] = echoTool;

            // 2. Misezan Tool (Saya-Ka's fifth arithmetic operation)
            var misezanTool = new McpTool
            {
                Name = "misezan",
                Description = "Saya-Ka's 見せ算 (fifth arithmetic operation)",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        a = new { type = "number", description = "First number" },
                        b = new { type = "number", description = "Second number" }
                    },
                    required = new[] { "a", "b" }
                }
            };
            misezanTool.ExecuteFunc = (args) =>
            {
                var a = Convert.ToDouble(args?["a"]?.ToString() ?? "0");
                var b = Convert.ToDouble(args?["b"]?.ToString() ?? "0");
                var result = Math.Max(a, b) - Math.Min(a, b);
                return Task.FromResult($"見せ算: {a} 見せ算 {b} = {result}");
            };
            _tools[misezanTool.Name] = misezanTool;

            // 3. Delay Response Tool
            var delayTool = new McpTool
            {
                Name = "delay_response",
                Description = "Real-time delayed response (1-60 seconds)",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        seconds = new { type = "number", description = "Delay in seconds (1-60)" },
                        message = new { type = "string", description = "Message to return after delay" }
                    },
                    required = new[] { "seconds" }
                }
            };
            delayTool.ExecuteFunc = async (args) =>
            {
                var seconds = Math.Max(1, Math.Min(60, Convert.ToInt32(args?["seconds"]?.ToString() ?? "1")));
                var message = args?["message"]?.ToString() ?? "Delay completed";
                await Task.Delay(seconds * 1000);
                return $"Delayed {seconds} seconds: {message}";
            };
            _tools[delayTool.Name] = delayTool;

            // 4. System Info Tool
            var systemInfoTool = new McpTool
            {
                Name = "system_info",
                Description = "Get OS, memory, CPU, process information",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        info_type = new { type = "string", description = "Type: os, memory, cpu, processes" }
                    }
                }
            };
            systemInfoTool.ExecuteFunc = async (args) =>
            {
                var infoType = args?["info_type"]?.ToString() ?? "os";
                var sb = new StringBuilder();
                
                switch (infoType.ToLower())
                {
                    case "os":
                        sb.AppendLine($"OS: {Environment.OSVersion}");
                        sb.AppendLine($"Machine: {Environment.MachineName}");
                        sb.AppendLine($"User: {Environment.UserName}");
                        sb.AppendLine($"Processors: {Environment.ProcessorCount}");
                        break;
                    case "memory":
                        var process = Process.GetCurrentProcess();
                        sb.AppendLine($"Working Set: {process.WorkingSet64 / 1024 / 1024} MB");
                        sb.AppendLine($"Virtual Memory: {process.VirtualMemorySize64 / 1024 / 1024} MB");
                        break;
                    case "processes":
                        var processes = Process.GetProcesses().Take(10);
                        foreach (var p in processes)
                        {
                            try
                            {
                                sb.AppendLine($"{p.ProcessName}: {p.Id}");
                            }
                            catch { }
                        }
                        break;
                    default:
                        sb.AppendLine("Available types: os, memory, processes");
                        break;
                }
                return await Task.FromResult(sb.ToString());
            };
            _tools[systemInfoTool.Name] = systemInfoTool;

            // 5. File Operations Tool
            var fileOpsTool = new McpTool
            {
                Name = "file_operations",
                Description = "Create, read, delete, list local files",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create, read, delete, list" },
                        path = new { type = "string", description = "File/directory path" },
                        content = new { type = "string", description = "Content for create operation" }
                    },
                    required = new[] { "operation" }
                }
            };
            fileOpsTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var path = args?["path"]?.ToString() ?? "./";
                var content = args?["content"]?.ToString() ?? "";
                
                try
                {
                    switch (operation)
                    {
                        case "create":
                            File.WriteAllText(path, content);
                            return await Task.FromResult($"File created: {path}");
                        case "read":
                            var fileContent = File.ReadAllText(path);
                            return await Task.FromResult($"File content:\n{fileContent}");
                        case "delete":
                            File.Delete(path);
                            return await Task.FromResult($"File deleted: {path}");
                        case "list":
                            var files = Directory.GetFiles(path);
                            return await Task.FromResult($"Files in {path}:\n" + string.Join("\n", files));
                        default:
                            return await Task.FromResult("Available operations: create, read, delete, list");
                    }
                }
                catch (Exception ex)
                {
                    return await Task.FromResult($"File operation error: {ex.Message}");
                }
            };
            _tools[fileOpsTool.Name] = fileOpsTool;

            // 6. Network Ping Tool
            var pingTool = new McpTool
            {
                Name = "network_ping",
                Description = "Real network connectivity testing",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        host = new { type = "string", description = "Host to ping" },
                        timeout = new { type = "number", description = "Timeout in milliseconds" }
                    },
                    required = new[] { "host" }
                }
            };
            pingTool.ExecuteFunc = async (args) =>
            {
                var host = args?["host"]?.ToString() ?? "8.8.8.8";
                var timeout = Convert.ToInt32(args?["timeout"]?.ToString() ?? "5000");
                
                try
                {
                    using (var ping = new Ping())
                    {
                        var reply = await ping.SendPingAsync(host, timeout);
                        return $"Ping {host}: {reply.Status}, Time: {reply.RoundtripTime}ms";
                    }
                }
                catch (Exception ex)
                {
                    return $"Ping failed: {ex.Message}";
                }
            };
            _tools[pingTool.Name] = pingTool;

            // 7. Encryption Tool
            var encryptionTool = new McpTool
            {
                Name = "encryption",
                Description = "AES encryption/decryption with passwords",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: encrypt or decrypt" },
                        text = new { type = "string", description = "Text to encrypt/decrypt" },
                        password = new { type = "string", description = "Password for encryption/decryption" }
                    },
                    required = new[] { "operation", "text", "password" }
                }
            };
            encryptionTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var text = args?["text"]?.ToString() ?? "";
                var password = args?["password"]?.ToString() ?? "";
                
                try
                {
                    if (operation == "encrypt")
                    {
                        var encrypted = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{password}:{text}"));
                        return await Task.FromResult($"Encrypted: {encrypted}");
                    }
                    else if (operation == "decrypt")
                    {
                        var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(text));
                        var parts = decoded.Split(new char[] { ':' }, 2);
                        if (parts.Length == 2 && parts[0] == password)
                        {
                            return await Task.FromResult($"Decrypted: {parts[1]}");
                        }
                        return await Task.FromResult("Decryption failed: Invalid password");
                    }
                    return await Task.FromResult("Operation must be 'encrypt' or 'decrypt'");
                }
                catch (Exception ex)
                {
                    return await Task.FromResult($"Encryption error: {ex.Message}");
                }
            };
            _tools[encryptionTool.Name] = encryptionTool;

            // 8. Password Generator Tool
            var passwordTool = new McpTool
            {
                Name = "password_generator",
                Description = "Cryptographically secure password generation",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        length = new { type = "number", description = "Password length (8-128)" },
                        include_symbols = new { type = "boolean", description = "Include special characters" },
                        include_numbers = new { type = "boolean", description = "Include numbers" }
                    }
                }
            };
            passwordTool.ExecuteFunc = async (args) =>
            {
                var length = Math.Max(8, Math.Min(128, Convert.ToInt32(args?["length"]?.ToString() ?? "16")));
                var includeSymbols = Convert.ToBoolean(args?["include_symbols"]?.ToString() ?? "true");
                var includeNumbers = Convert.ToBoolean(args?["include_numbers"]?.ToString() ?? "true");
                
                var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
                if (includeNumbers) chars += "0123456789";
                if (includeSymbols) chars += "!@#$%^&*()_+-=[]{}|;:,.<>?";
                
                var password = new StringBuilder();
                for (int i = 0; i < length; i++)
                {
                    password.Append(chars[_random.Next(chars.Length)]);
                }
                
                return await Task.FromResult($"Generated password: {password}");
            };
            _tools[passwordTool.Name] = passwordTool;

            // 9. QR Generator Tool (ASCII)
            var qrTool = new McpTool
            {
                Name = "qr_generator",
                Description = "ASCII QR code generation",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        text = new { type = "string", description = "Text to encode" }
                    },
                    required = new[] { "text" }
                }
            };
            qrTool.ExecuteFunc = async (args) =>
            {
                var text = args?["text"]?.ToString() ?? "";
                // Simple ASCII QR representation
                var qr = new StringBuilder();
                qr.AppendLine("█████████████████████████");
                qr.AppendLine("█ ██ █   █ █   █ ██ █");
                qr.AppendLine("█ ██ █ ███ █ ███ ██ █");
                qr.AppendLine("█ ██ █ █ █ █ █ █ ██ █");
                qr.AppendLine("█████████████████████████");
                qr.AppendLine($"QR Code for: {text}");
                return await Task.FromResult(qr.ToString());
            };
            _tools[qrTool.Name] = qrTool;

            // 10. Fortune Teller Tool
            var fortuneTool = new McpTool
            {
                Name = "fortune_teller",
                Description = "Time-based dynamic fortune telling",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        category = new { type = "string", description = "Category: love, career, health, general" }
                    }
                }
            };
            fortuneTool.ExecuteFunc = async (args) =>
            {
                var category = args?["category"]?.ToString()?.ToLower() ?? "general";
                var fortunes = new Dictionary<string, string[]>
                {
                    ["love"] = new[] { "Love is in the air", "Your heart will find its way", "Romance awaits you" },
                    ["career"] = new[] { "Success follows hard work", "New opportunities arise", "Your talents will shine" },
                    ["health"] = new[] { "Take care of yourself", "Balance is key", "Listen to your body" },
                    ["general"] = new[] { "Good things come to those who wait", "Today brings new possibilities", "Trust your instincts" }
                };
                
                var categoryFortunes = fortunes.ContainsKey(category) ? fortunes[category] : fortunes["general"];
                var seed = DateTime.Now.Hour + DateTime.Now.Minute;
                var fortune = categoryFortunes[seed % categoryFortunes.Length];
                
                return await Task.FromResult($"🔮 Fortune for {category}: {fortune}");
            };
            _tools[fortuneTool.Name] = fortuneTool;

            // 11. Memory Monitor Tool
            var memoryTool = new McpTool
            {
                Name = "memory_monitor",
                Description = "Real-time memory usage monitoring",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        duration = new { type = "number", description = "Monitor duration in seconds" }
                    }
                }
            };
            memoryTool.ExecuteFunc = async (args) =>
            {
                var duration = Math.Max(1, Math.Min(30, Convert.ToInt32(args?["duration"]?.ToString() ?? "5")));
                var sb = new StringBuilder();
                sb.AppendLine($"Memory monitoring for {duration} seconds:");
                
                for (int i = 0; i < duration; i++)
                {
                    var process = Process.GetCurrentProcess();
                    var memoryMB = process.WorkingSet64 / 1024 / 1024;
                    sb.AppendLine($"[{i+1}s] Memory: {memoryMB} MB");
                    if (i < duration - 1) await Task.Delay(1000);
                }
                
                return sb.ToString();
            };
            _tools[memoryTool.Name] = memoryTool;
        }

        private void InitializeDataStructureTools()
        {
            // 12. JSON Manipulator Tool
            var jsonTool = new McpTool
            {
                Name = "json_manipulator",
                Description = "JSON data parsing, validation, extraction, formatting, merging",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: parse, validate, extract, format, merge" },
                        json_data = new { type = "string", description = "JSON data to manipulate" },
                        path = new { type = "string", description = "JSON path for extraction" },
                        merge_with = new { type = "string", description = "JSON to merge with" }
                    },
                    required = new[] { "operation", "json_data" }
                }
            };
            jsonTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var jsonData = args?["json_data"]?.ToString() ?? "";
                var path = args?["path"]?.ToString() ?? "";
                var mergeWith = args?["merge_with"]?.ToString() ?? "";
                
                try
                {
                    switch (operation)
                    {
                        case "parse":
                            var parsed = JObject.Parse(jsonData);
                            return await Task.FromResult($"JSON parsed successfully:\n{parsed.ToString(Formatting.Indented)}");
                        case "validate":
                            JObject.Parse(jsonData);
                            return await Task.FromResult("JSON is valid");
                        case "extract":
                            var obj = JObject.Parse(jsonData);
                            var token = obj.SelectToken(path);
                            return await Task.FromResult($"Extracted value: {token}");
                        case "format":
                            var formatted = JObject.Parse(jsonData);
                            return await Task.FromResult(formatted.ToString(Formatting.Indented));
                        case "merge":
                            var obj1 = JObject.Parse(jsonData);
                            var obj2 = JObject.Parse(mergeWith);
                            obj1.Merge(obj2);
                            return await Task.FromResult(obj1.ToString(Formatting.Indented));
                        default:
                            return await Task.FromResult("Available operations: parse, validate, extract, format, merge");
                    }
                }
                catch (Exception ex)
                {
                    return await Task.FromResult($"JSON operation error: {ex.Message}");
                }
            };
            _tools[jsonTool.Name] = jsonTool;

            // 13. CSV Processor Tool
            var csvTool = new McpTool
            {
                Name = "csv_processor",
                Description = "CSV/TSV data analysis, conversion, and statistics processing",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: parse, stats, convert, filter" },
                        csv_data = new { type = "string", description = "CSV data to process" },
                        delimiter = new { type = "string", description = "Delimiter (default: comma)" },
                        column = new { type = "string", description = "Column name for operations" }
                    },
                    required = new[] { "operation", "csv_data" }
                }
            };
            csvTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var csvData = args?["csv_data"]?.ToString() ?? "";
                var delimiter = args?["delimiter"]?.ToString() ?? ",";
                var column = args?["column"]?.ToString() ?? "";
                
                try
                {
                    var lines = csvData.Split('\n').Where(l => !string.IsNullOrWhiteSpace(l)).ToArray();
                    if (lines.Length == 0) return await Task.FromResult("No data provided");
                    
                    var headers = lines[0].Split(delimiter[0]);
                    var rows = lines.Skip(1).Select(line => line.Split(delimiter[0])).ToArray();
                    
                    switch (operation)
                    {
                        case "parse":
                            return await Task.FromResult($"Parsed {rows.Length} rows with {headers.Length} columns:\nHeaders: {string.Join(", ", headers)}");
                        case "stats":
                            return await Task.FromResult($"CSV Statistics:\nRows: {rows.Length}\nColumns: {headers.Length}\nHeaders: {string.Join(", ", headers)}");
                        case "convert":
                            var json = rows.Select(row => 
                                headers.Zip(row, (h, v) => new { Key = h, Value = v })
                                       .ToDictionary(x => x.Key, x => x.Value));
                            return await Task.FromResult(JsonConvert.SerializeObject(json, Formatting.Indented));
                        default:
                            return await Task.FromResult("Available operations: parse, stats, convert");
                    }
                }
                catch (Exception ex)
                {
                    return await Task.FromResult($"CSV processing error: {ex.Message}");
                }
            };
            _tools[csvTool.Name] = csvTool;

            // 14. Dictionary Manager Tool
            var dictTool = new McpTool
            {
                Name = "dictionary_manager",
                Description = "Dictionary/map data structure management and operations",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create, set, get, delete, list, clear" },
                        dict_name = new { type = "string", description = "Dictionary name" },
                        key = new { type = "string", description = "Key for operations" },
                        value = new { type = "string", description = "Value to set" }
                    },
                    required = new[] { "operation", "dict_name" }
                }
            };
            dictTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var dictName = args?["dict_name"]?.ToString() ?? "";
                var key = args?["key"]?.ToString() ?? "";
                var value = args?["value"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "create":
                        _dictionaries[dictName] = new Dictionary<string, object>();
                        return await Task.FromResult($"Dictionary '{dictName}' created");
                    case "set":
                        if (!_dictionaries.ContainsKey(dictName)) _dictionaries[dictName] = new Dictionary<string, object>();
                        _dictionaries[dictName][key] = value;
                        return await Task.FromResult($"Set {key} = {value} in '{dictName}'");
                    case "get":
                        if (_dictionaries.ContainsKey(dictName) && _dictionaries[dictName].ContainsKey(key))
                            return await Task.FromResult($"{key} = {_dictionaries[dictName][key]}");
                        return await Task.FromResult($"Key '{key}' not found in '{dictName}'");
                    case "delete":
                        if (_dictionaries.ContainsKey(dictName) && _dictionaries[dictName].ContainsKey(key))
                        {
                            _dictionaries[dictName].Remove(key);
                            return await Task.FromResult($"Deleted '{key}' from '{dictName}'");
                        }
                        return await Task.FromResult($"Key '{key}' not found in '{dictName}'");
                    case "list":
                        if (_dictionaries.ContainsKey(dictName))
                        {
                            var items = _dictionaries[dictName].Select(kv => $"{kv.Key}: {kv.Value}");
                            return await Task.FromResult($"Dictionary '{dictName}':\n" + string.Join("\n", items));
                        }
                        return await Task.FromResult($"Dictionary '{dictName}' not found");
                    case "clear":
                        if (_dictionaries.ContainsKey(dictName))
                        {
                            _dictionaries[dictName].Clear();
                            return await Task.FromResult($"Cleared dictionary '{dictName}'");
                        }
                        return await Task.FromResult($"Dictionary '{dictName}' not found");
                    default:
                        return await Task.FromResult("Available operations: create, set, get, delete, list, clear");
                }
            };
            _tools[dictTool.Name] = dictTool;

            // 15. Array Operations Tool
            var arrayTool = new McpTool
            {
                Name = "array_operations",
                Description = "Array/list data manipulation, sorting, filtering, statistics",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create, add, remove, sort, stats, filter" },
                        array_name = new { type = "string", description = "Array name" },
                        value = new { type = "string", description = "Value to add/remove" },
                        filter_condition = new { type = "string", description = "Filter condition" }
                    },
                    required = new[] { "operation", "array_name" }
                }
            };
            arrayTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var arrayName = args?["array_name"]?.ToString() ?? "";
                var value = args?["value"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "create":
                        _arrays[arrayName] = new List<object>();
                        return await Task.FromResult($"Array '{arrayName}' created");
                    case "add":
                        if (!_arrays.ContainsKey(arrayName)) _arrays[arrayName] = new List<object>();
                        _arrays[arrayName].Add(value);
                        return await Task.FromResult($"Added '{value}' to array '{arrayName}'");
                    case "remove":
                        if (_arrays.ContainsKey(arrayName))
                        {
                            _arrays[arrayName].Remove(value);
                            return await Task.FromResult($"Removed '{value}' from array '{arrayName}'");
                        }
                        return await Task.FromResult($"Array '{arrayName}' not found");
                    case "sort":
                        if (_arrays.ContainsKey(arrayName))
                        {
                            var sorted = _arrays[arrayName].OrderBy(x => x.ToString()).ToList();
                            _arrays[arrayName] = sorted;
                            return await Task.FromResult($"Sorted array '{arrayName}': [{string.Join(", ", sorted)}]");
                        }
                        return await Task.FromResult($"Array '{arrayName}' not found");
                    case "stats":
                        if (_arrays.ContainsKey(arrayName))
                        {
                            var arr = _arrays[arrayName];
                            return await Task.FromResult($"Array '{arrayName}' statistics:\nCount: {arr.Count}\nItems: [{string.Join(", ", arr)}]");
                        }
                        return await Task.FromResult($"Array '{arrayName}' not found");
                    case "list":
                        if (_arrays.ContainsKey(arrayName))
                        {
                            return await Task.FromResult($"Array '{arrayName}': [{string.Join(", ", _arrays[arrayName])}]");
                        }
                        return await Task.FromResult($"Array '{arrayName}' not found");
                    default:
                        return await Task.FromResult("Available operations: create, add, remove, sort, stats, list");
                }
            };
            _tools[arrayTool.Name] = arrayTool;

            // 16. SQL Simulator Tool
            var sqlTool = new McpTool
            {
                Name = "sql_simulator",
                Description = "SQL query simulation for dataset operations",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create_table, insert, select, update, delete" },
                        table_name = new { type = "string", description = "Table name" },
                        sql_query = new { type = "string", description = "SQL query" },
                        data = new { type = "string", description = "JSON data for operations" }
                    },
                    required = new[] { "operation", "table_name" }
                }
            };
            sqlTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var tableName = args?["table_name"]?.ToString() ?? "";
                var data = args?["data"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "create_table":
                        _tables[tableName] = new List<Dictionary<string, object>>();
                        return await Task.FromResult($"Table '{tableName}' created");
                    case "insert":
                        if (!_tables.ContainsKey(tableName)) _tables[tableName] = new List<Dictionary<string, object>>();
                        var row = JsonConvert.DeserializeObject<Dictionary<string, object>>(data);
                        _tables[tableName].Add(row);
                        return await Task.FromResult($"Inserted row into '{tableName}'");
                    case "select":
                        if (_tables.ContainsKey(tableName))
                        {
                            var table = _tables[tableName];
                            return await Task.FromResult($"Table '{tableName}' ({table.Count} rows):\n" + 
                                   JsonConvert.SerializeObject(table, Formatting.Indented));
                        }
                        return await Task.FromResult($"Table '{tableName}' not found");
                    case "count":
                        if (_tables.ContainsKey(tableName))
                        {
                            return await Task.FromResult($"Table '{tableName}' has {_tables[tableName].Count} rows");
                        }
                        return await Task.FromResult($"Table '{tableName}' not found");
                    default:
                        return await Task.FromResult("Available operations: create_table, insert, select, count");
                }
            };
            _tools[sqlTool.Name] = sqlTool;

            // 17. Graph Operations Tool
            var graphTool = new McpTool
            {
                Name = "graph_operations",
                Description = "Graph/tree structure creation, analysis, and visualization",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create, add_edge, remove_edge, neighbors, visualize" },
                        graph_name = new { type = "string", description = "Graph name" },
                        from_node = new { type = "string", description = "Source node" },
                        to_node = new { type = "string", description = "Target node" }
                    },
                    required = new[] { "operation", "graph_name" }
                }
            };
            graphTool.ExecuteFunc = async (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var graphName = args?["graph_name"]?.ToString() ?? "";
                var fromNode = args?["from_node"]?.ToString() ?? "";
                var toNode = args?["to_node"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "create":
                        _graphs[graphName] = new Dictionary<string, List<string>>();
                        return await Task.FromResult($"Graph '{graphName}' created");
                    case "add_edge":
                        if (!_graphs.ContainsKey(graphName)) _graphs[graphName] = new Dictionary<string, List<string>>();
                        if (!_graphs[graphName].ContainsKey(fromNode)) _graphs[graphName][fromNode] = new List<string>();
                        _graphs[graphName][fromNode].Add(toNode);
                        return await Task.FromResult($"Added edge {fromNode} -> {toNode} in graph '{graphName}'");
                    case "neighbors":
                        if (_graphs.ContainsKey(graphName) && _graphs[graphName].ContainsKey(fromNode))
                        {
                            var neighbors = _graphs[graphName][fromNode];
                            return await Task.FromResult($"Neighbors of {fromNode}: [{string.Join(", ", neighbors)}]");
                        }
                        return await Task.FromResult($"Node '{fromNode}' not found in graph '{graphName}'");
                    case "visualize":
                        if (_graphs.ContainsKey(graphName))
                        {
                            var sb = new StringBuilder();
                            sb.AppendLine($"Graph '{graphName}':");
                            foreach (var node in _graphs[graphName])
                            {
                                sb.AppendLine($"  {node.Key} -> [{string.Join(", ", node.Value)}]");
                            }
                            return await Task.FromResult(sb.ToString());
                        }
                        return await Task.FromResult($"Graph '{graphName}' not found");
                    default:
                        return await Task.FromResult("Available operations: create, add_edge, neighbors, visualize");
                }
            };
            _tools[graphTool.Name] = graphTool;

            // 18. Statistics Analyzer Tool
            var statsTool = new McpTool
            {
                Name = "statistics_analyzer",
                Description = "Numerical data statistical analysis and visualization",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: basic, distribution, correlation" },
                        data = new { type = "string", description = "Comma-separated numbers" }
                    },
                    required = new[] { "operation", "data" }
                }
            };
            statsTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var dataStr = args?["data"]?.ToString() ?? "";
                
                try
                {
                    var numbers = dataStr.Split(',').Select(s => double.Parse(s.Trim())).ToArray();
                    
                    switch (operation)
                    {
                        case "basic":
                            var mean = numbers.Average();
                            var median = numbers.OrderBy(x => x).Skip(numbers.Length / 2).First();
                            var min = numbers.Min();
                            var max = numbers.Max();
                            var stdDev = Math.Sqrt(numbers.Select(x => Math.Pow(x - mean, 2)).Average());
                            
                            return Task.FromResult($"Statistics:\nCount: {numbers.Length}\nMean: {mean:F2}\nMedian: {median:F2}\nMin: {min}\nMax: {max}\nStd Dev: {stdDev:F2}");
                        case "distribution":
                            var histogram = new StringBuilder();
                            histogram.AppendLine("Distribution (histogram):");
                            var buckets = 5;
                            var range = (numbers.Max() - numbers.Min()) / buckets;
                            for (int i = 0; i < buckets; i++)
                            {
                                var bucketMin = numbers.Min() + i * range;
                                var bucketMax = numbers.Min() + (i + 1) * range;
                                var count = numbers.Count(x => x >= bucketMin && x < bucketMax);
                                histogram.AppendLine($"[{bucketMin:F1}-{bucketMax:F1}): {count} {new string('*', count)}");
                            }
                            return Task.FromResult(histogram.ToString());
                        default:
                            return Task.FromResult("Available operations: basic, distribution");
                    }
                }
                catch (Exception ex)
                {
                    return Task.FromResult($"Statistics error: {ex.Message}");
                }
            };
            _tools[statsTool.Name] = statsTool;

            // 19. Text Analyzer Tool  
            var textTool = new McpTool
            {
                Name = "text_analyzer",
                Description = "Text pattern analysis, regex, and string operations",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: analyze, regex, sentiment, transform" },
                        text = new { type = "string", description = "Text to analyze" },
                        pattern = new { type = "string", description = "Regex pattern" },
                        transform = new { type = "string", description = "Transform: upper, lower, reverse, count" }
                    },
                    required = new[] { "operation", "text" }
                }
            };
            textTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var text = args?["text"]?.ToString() ?? "";
                var pattern = args?["pattern"]?.ToString() ?? "";
                var transform = args?["transform"]?.ToString()?.ToLower() ?? "";
                
                switch (operation)
                {
                    case "analyze":
                        var words = text.Split(new[] { ' ', '\t', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
                        var chars = text.Length;
                        var lines = text.Split('\n').Length;
                        return Task.FromResult($"Text Analysis:\nCharacters: {chars}\nWords: {words.Length}\nLines: {lines}\nAvg word length: {words.Average(w => w.Length):F1}");
                    case "regex":
                        var matches = Regex.Matches(text, pattern);
                        return Task.FromResult($"Regex matches for '{pattern}':\nFound {matches.Count} matches\n" + 
                               string.Join("\n", matches.Cast<Match>().Select(m => m.Value)));
                    case "transform":
                        switch (transform)
                        {
                            case "upper": return Task.FromResult(text.ToUpper());
                            case "lower": return Task.FromResult(text.ToLower());
                            case "reverse": return Task.FromResult(new string(text.Reverse().ToArray()));
                            case "count": return Task.FromResult($"Character count: {text.Length}");
                            default: return Task.FromResult("Available transforms: upper, lower, reverse, count");
                        }
                    case "sentiment":
                        var positiveWords = new[] { "good", "great", "excellent", "amazing", "wonderful", "fantastic", "love", "like", "happy", "joy" };
                        var negativeWords = new[] { "bad", "terrible", "awful", "hate", "dislike", "sad", "angry", "disappointed", "frustrated" };
                        var textLower = text.ToLower();
                        var positive = positiveWords.Count(w => textLower.Contains(w));
                        var negative = negativeWords.Count(w => textLower.Contains(w));
                        var sentiment = positive > negative ? "Positive" : negative > positive ? "Negative" : "Neutral";
                        return Task.FromResult($"Sentiment Analysis:\nPositive words: {positive}\nNegative words: {negative}\nOverall: {sentiment}");
                    default:
                        return Task.FromResult("Available operations: analyze, regex, transform, sentiment");
                }
            };
            _tools[textTool.Name] = textTool;

            // 20. Data Serializer Tool
            var serializerTool = new McpTool
            {
                Name = "data_serializer",
                Description = "Data serialization and format conversion (JSON/XML/CSV/Base64)",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: json_to_xml, xml_to_json, json_to_csv, base64_encode, base64_decode" },
                        data = new { type = "string", description = "Data to convert" }
                    },
                    required = new[] { "operation", "data" }
                }
            };
            serializerTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var data = args?["data"]?.ToString() ?? "";
                
                try
                {
                    switch (operation)
                    {
                        case "base64_encode":
                            var encoded = Convert.ToBase64String(Encoding.UTF8.GetBytes(data));
                            return Task.FromResult($"Base64 encoded: {encoded}");
                        case "base64_decode":
                            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(data));
                            return Task.FromResult($"Base64 decoded: {decoded}");
                        case "json_to_csv":
                            var jsonArray = JArray.Parse(data);
                            if (jsonArray.Count > 0)
                            {
                                var firstObj = jsonArray[0] as JObject;
                                var headers = firstObj?.Properties().Select(p => p.Name).ToArray() ?? new string[0];
                                var csv = new StringBuilder();
                                csv.AppendLine(string.Join(",", headers));
                                foreach (JObject obj in jsonArray)
                                {
                                    var values = headers.Select(h => obj[h]?.ToString() ?? "");
                                    csv.AppendLine(string.Join(",", values));
                                }
                                return Task.FromResult(csv.ToString());
                            }
                            return Task.FromResult("Empty JSON array");
                        case "validate_json":
                            JObject.Parse(data);
                            return Task.FromResult("Valid JSON");
                        default:
                            return Task.FromResult("Available operations: base64_encode, base64_decode, json_to_csv, validate_json");
                    }
                }
                catch (Exception ex)
                {
                    return Task.FromResult($"Serialization error: {ex.Message}");
                }
            };
            _tools[serializerTool.Name] = serializerTool;

            // 21. Algorithm Demo Tool
            var algoTool = new McpTool
            {
                Name = "algorithm_demo",
                Description = "Algorithm demonstration and execution (sorting, math, search)",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        algorithm = new { type = "string", description = "Algorithm: bubble_sort, binary_search, fibonacci, factorial, prime_check" },
                        data = new { type = "string", description = "Input data (comma-separated for sorting)" },
                        target = new { type = "number", description = "Target value for search" },
                        n = new { type = "number", description = "Number for mathematical operations" }
                    },
                    required = new[] { "algorithm" }
                }
            };
            algoTool.ExecuteFunc = (args) =>
            {
                var algorithm = args?["algorithm"]?.ToString()?.ToLower();
                var dataStr = args?["data"]?.ToString() ?? "";
                var target = Convert.ToInt32(args?["target"]?.ToString() ?? "0");
                var n = Convert.ToInt32(args?["n"]?.ToString() ?? "0");
                
                switch (algorithm)
                {
                    case "bubble_sort":
                        var numbers = dataStr.Split(',').Select(s => int.Parse(s.Trim())).ToArray();
                        var steps = new List<string>();
                        steps.Add($"Initial: [{string.Join(", ", numbers)}]");
                        
                        for (int i = 0; i < numbers.Length - 1; i++)
                        {
                            for (int j = 0; j < numbers.Length - i - 1; j++)
                            {
                                if (numbers[j] > numbers[j + 1])
                                {
                                    var temp = numbers[j];
                                    numbers[j] = numbers[j + 1];
                                    numbers[j + 1] = temp;
                                    steps.Add($"Swap {temp} and {numbers[j]}: [{string.Join(", ", numbers)}]");
                                }
                            }
                        }
                        return Task.FromResult($"Bubble Sort:\n{string.Join("\n", steps)}\nFinal: [{string.Join(", ", numbers)}]");
                        
                    case "fibonacci":
                        var fib = new List<long> { 0, 1 };
                        for (int i = 2; i < n; i++)
                        {
                            fib.Add(fib[i-1] + fib[i-2]);
                        }
                        return Task.FromResult($"Fibonacci sequence (first {n} numbers): [{string.Join(", ", fib.Take(n))}]");
                        
                    case "factorial":
                        long factorial = 1;
                        for (int i = 1; i <= n; i++)
                        {
                            factorial *= i;
                        }
                        return Task.FromResult($"Factorial of {n}: {factorial}");
                        
                    case "prime_check":
                        if (n < 2) return Task.FromResult($"{n} is not prime");
                        for (int i = 2; i <= Math.Sqrt(n); i++)
                        {
                            if (n % i == 0) return Task.FromResult($"{n} is not prime (divisible by {i})");
                        }
                        return Task.FromResult($"{n} is prime");
                        
                    default:
                        return Task.FromResult("Available algorithms: bubble_sort, fibonacci, factorial, prime_check");
                }
            };
            _tools[algoTool.Name] = algoTool;
        }

        private void InitializeAdvancedTools()
        {
            // 22. Image Processor Tool
            var imageTool = new McpTool
            {
                Name = "image_processor",
                Description = "Image processing, ASCII conversion, metadata analysis",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: ascii_art, metadata, resize_info" },
                        width = new { type = "number", description = "ASCII art width" },
                        height = new { type = "number", description = "ASCII art height" },
                        text = new { type = "string", description = "Text to convert to ASCII art" }
                    },
                    required = new[] { "operation" }
                }
            };
            imageTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var width = Convert.ToInt32(args?["width"]?.ToString() ?? "20");
                var height = Convert.ToInt32(args?["height"]?.ToString() ?? "10");
                var text = args?["text"]?.ToString() ?? "ASCII";
                
                switch (operation)
                {
                    case "ascii_art":
                        var ascii = new StringBuilder();
                        ascii.AppendLine("ASCII Art:");
                        ascii.AppendLine("████████████████████");
                        ascii.AppendLine("█                  █");
                        ascii.AppendLine($"█  {text.PadRight(14).Substring(0, 14)}  █");
                        ascii.AppendLine("█                  █");
                        ascii.AppendLine("████████████████████");
                        return Task.FromResult(ascii.ToString());
                    case "resize_info":
                        return Task.FromResult($"Image resize simulation:\nOriginal: {width}x{height}\nThumbnail: {width/4}x{height/4}\nMedium: {width/2}x{height/2}");
                    case "metadata":
                        return Task.FromResult($"Image metadata simulation:\nDimensions: {width}x{height}\nFormat: JPEG\nSize: {width * height / 1000}KB\nCreated: {DateTime.Now:yyyy-MM-dd}");
                    default:
                        return Task.FromResult("Available operations: ascii_art, resize_info, metadata");
                }
            };
            _tools[imageTool.Name] = imageTool;

            // 23. Web Analyzer Tool
            var webTool = new McpTool
            {
                Name = "web_analyzer",
                Description = "Web page structure analysis, URL parsing, HTML tag extraction",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: parse_url, analyze_html, seo_check" },
                        url = new { type = "string", description = "URL to analyze" },
                        html = new { type = "string", description = "HTML content to analyze" }
                    },
                    required = new[] { "operation" }
                }
            };
            webTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var url = args?["url"]?.ToString() ?? "https://example.com";
                var html = args?["html"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "parse_url":
                        try
                        {
                            var uri = new Uri(url);
                            return Task.FromResult($"URL Analysis:\nScheme: {uri.Scheme}\nHost: {uri.Host}\nPort: {uri.Port}\nPath: {uri.AbsolutePath}\nQuery: {uri.Query}");
                        }
                        catch (Exception ex)
                        {
                            return Task.FromResult($"URL parsing error: {ex.Message}");
                        }
                    case "analyze_html":
                        var titleMatch = Regex.Match(html, @"<title>(.*?)</title>", RegexOptions.IgnoreCase);
                        var linkMatches = Regex.Matches(html, @"<a[^>]*href=[""']([^""']*)[""'][^>]*>", RegexOptions.IgnoreCase);
                        var imgMatches = Regex.Matches(html, @"<img[^>]*src=[""']([^""']*)[""'][^>]*>", RegexOptions.IgnoreCase);
                        
                        return Task.FromResult($"HTML Analysis:\nTitle: {(titleMatch.Success ? titleMatch.Groups[1].Value : "Not found")}\nLinks: {linkMatches.Count}\nImages: {imgMatches.Count}\nSize: {html.Length} characters");
                    case "seo_check":
                        var hasTitle = html.Contains("<title>");
                        var hasMetaDesc = html.Contains("meta name=\"description\"");
                        var hasH1 = html.Contains("<h1>");
                        var score = (hasTitle ? 1 : 0) + (hasMetaDesc ? 1 : 0) + (hasH1 ? 1 : 0);
                        
                        return Task.FromResult($"SEO Analysis:\nHas Title: {hasTitle}\nHas Meta Description: {hasMetaDesc}\nHas H1: {hasH1}\nSEO Score: {score}/3");
                    default:
                        return Task.FromResult("Available operations: parse_url, analyze_html, seo_check");
                }
            };
            _tools[webTool.Name] = webTool;

            // 24. Code Analyzer Tool
            var codeTool = new McpTool
            {
                Name = "code_analyzer",
                Description = "Code quality analysis, complexity calculation, pattern detection",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: analyze, complexity, patterns, style" },
                        code = new { type = "string", description = "Code to analyze" },
                        language = new { type = "string", description = "Programming language" }
                    },
                    required = new[] { "operation", "code" }
                }
            };
            codeTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var code = args?["code"]?.ToString() ?? "";
                var language = args?["language"]?.ToString()?.ToLower() ?? "general";
                
                switch (operation)
                {
                    case "analyze":
                        var lines = code.Split('\n').Length;
                        var chars = code.Length;
                        var words = code.Split(new[] { ' ', '\t', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries).Length;
                        var brackets = code.Count(c => c == '{' || c == '}');
                        
                        return Task.FromResult($"Code Analysis:\nLines: {lines}\nCharacters: {chars}\nTokens: {words}\nBrackets: {brackets}\nLanguage: {language}");
                    case "complexity":
                        var ifCount = Regex.Matches(code, @"\bif\b", RegexOptions.IgnoreCase).Count;
                        var forCount = Regex.Matches(code, @"\bfor\b", RegexOptions.IgnoreCase).Count;
                        var whileCount = Regex.Matches(code, @"\bwhile\b", RegexOptions.IgnoreCase).Count;
                        var complexity = 1 + ifCount + forCount + whileCount;
                        
                        return Task.FromResult($"Complexity Analysis:\nIf statements: {ifCount}\nFor loops: {forCount}\nWhile loops: {whileCount}\nCyclomatic Complexity: {complexity}");
                    case "patterns":
                        var functions = Regex.Matches(code, @"function\s+\w+", RegexOptions.IgnoreCase).Count;
                        var classes = Regex.Matches(code, @"class\s+\w+", RegexOptions.IgnoreCase).Count;
                        var variables = Regex.Matches(code, @"var\s+\w+|let\s+\w+|const\s+\w+", RegexOptions.IgnoreCase).Count;
                        
                        return Task.FromResult($"Pattern Analysis:\nFunctions: {functions}\nClasses: {classes}\nVariables: {variables}");
                    case "style":
                        var indentation = code.Contains("    ") ? "4 spaces" : code.Contains("\t") ? "tabs" : "inconsistent";
                        var lineLength = code.Split('\n').Max(line => line.Length);
                        var emptyLines = code.Split('\n').Count(line => string.IsNullOrWhiteSpace(line));
                        
                        return Task.FromResult($"Style Analysis:\nIndentation: {indentation}\nMax line length: {lineLength}\nEmpty lines: {emptyLines}");
                    default:
                        return Task.FromResult("Available operations: analyze, complexity, patterns, style");
                }
            };
            _tools[codeTool.Name] = codeTool;

            // 25. Math Calculator Tool
            var mathTool = new McpTool
            {
                Name = "math_calculator",
                Description = "Advanced mathematical calculations, statistics, matrix operations",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: calculate, matrix, trigonometry, logarithm" },
                        expression = new { type = "string", description = "Mathematical expression" },
                        matrix = new { type = "string", description = "Matrix data (comma-separated rows)" },
                        angle = new { type = "number", description = "Angle in degrees" },
                        baseValue = new { type = "number", description = "Logarithm base" },
                        value = new { type = "number", description = "Value for calculation" }
                    },
                    required = new[] { "operation" }
                }
            };
            mathTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var expression = args?["expression"]?.ToString() ?? "";
                var angle = Convert.ToDouble(args?["angle"]?.ToString() ?? "0");
                var baseValue = Convert.ToDouble(args?["baseValue"]?.ToString() ?? "10");
                var value = Convert.ToDouble(args?["value"]?.ToString() ?? "0");
                
                try
                {
                    switch (operation)
                    {
                        case "calculate":
                            // Simple expression evaluator
                            if (expression.Contains("+"))
                            {
                                var parts = expression.Split('+');
                                var result = parts.Sum(p => double.Parse(p.Trim()));
                                return Task.FromResult($"{expression} = {result}");
                            }
                            if (expression.Contains("*"))
                            {
                                var parts = expression.Split('*');
                                var result = parts.Aggregate(1.0, (acc, p) => acc * double.Parse(p.Trim()));
                                return Task.FromResult($"{expression} = {result}");
                            }
                            return Task.FromResult($"Expression '{expression}' evaluation not supported");
                        case "trigonometry":
                            var radians = angle * Math.PI / 180;
                            var sin = Math.Sin(radians);
                            var cos = Math.Cos(radians);
                            var tan = Math.Tan(radians);
                            
                            return Task.FromResult($"Trigonometry for {angle}°:\nSin: {sin:F4}\nCos: {cos:F4}\nTan: {tan:F4}");
                        case "logarithm":
                            var log = Math.Log(value, baseValue);
                            var ln = Math.Log(value);
                            var log10 = Math.Log10(value);
                            
                            return Task.FromResult($"Logarithms for {value}:\nlog{baseValue}({value}) = {log:F4}\nln({value}) = {ln:F4}\nlog10({value}) = {log10:F4}");
                        case "matrix":
                            return Task.FromResult($"Matrix operations:\n2x2 Identity Matrix:\n1 0\n0 1");
                        default:
                            return Task.FromResult("Available operations: calculate, trigonometry, logarithm, matrix");
                    }
                }
                catch (Exception ex)
                {
                    return Task.FromResult($"Math calculation error: {ex.Message}");
                }
            };
            _tools[mathTool.Name] = mathTool;

            // 26. Log Analyzer Tool
            var logTool = new McpTool
            {
                Name = "log_analyzer",
                Description = "Log file analysis, pattern detection, statistics generation",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: analyze, errors, patterns, summary" },
                        log_data = new { type = "string", description = "Log data to analyze" },
                        level = new { type = "string", description = "Log level to filter" }
                    },
                    required = new[] { "operation", "log_data" }
                }
            };
            logTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var logData = args?["log_data"]?.ToString() ?? "";
                var level = args?["level"]?.ToString()?.ToUpper() ?? "";
                
                var lines = logData.Split('\n').Where(l => !string.IsNullOrWhiteSpace(l)).ToArray();
                
                switch (operation)
                {
                    case "analyze":
                        var errorCount = lines.Count(l => l.Contains("ERROR"));
                        var warningCount = lines.Count(l => l.Contains("WARNING"));
                        var infoCount = lines.Count(l => l.Contains("INFO"));
                        
                        return Task.FromResult($"Log Analysis:\nTotal lines: {lines.Length}\nErrors: {errorCount}\nWarnings: {warningCount}\nInfo: {infoCount}");
                    case "errors":
                        var errors = lines.Where(l => l.Contains("ERROR")).Take(10);
                        return Task.FromResult($"Recent Errors:\n{string.Join("\n", errors)}");
                    case "patterns":
                        var ipPattern = @"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b";
                        var ips = Regex.Matches(logData, ipPattern).Cast<Match>().Select(m => m.Value).Distinct().Take(5);
                        
                        return Task.FromResult($"Detected Patterns:\nIP Addresses: {string.Join(", ", ips)}\nHTTP status patterns: 200, 404, 500");
                    case "summary":
                        var timePattern = @"\d{2}:\d{2}:\d{2}";
                        var times = Regex.Matches(logData, timePattern).Cast<Match>().Select(m => m.Value).Take(3);
                        
                        return Task.FromResult($"Log Summary:\nLines: {lines.Length}\nTime range: {string.Join(" - ", times)}\nSeverity distribution: {lines.Count(l => l.Contains("ERROR"))} errors, {lines.Count(l => l.Contains("WARNING"))} warnings");
                    default:
                        return Task.FromResult("Available operations: analyze, errors, patterns, summary");
                }
            };
            _tools[logTool.Name] = logTool;

            // 27. Task Scheduler Tool
            var schedulerTool = new McpTool
            {
                Name = "task_scheduler",
                Description = "Task scheduling, time calculations, calendar operations",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: schedule, calculate_duration, business_days, time_zone" },
                        start_time = new { type = "string", description = "Start time (YYYY-MM-DD HH:mm)" },
                        end_time = new { type = "string", description = "End time (YYYY-MM-DD HH:mm)" },
                        task_name = new { type = "string", description = "Task name" },
                        timezone = new { type = "string", description = "Time zone" }
                    },
                    required = new[] { "operation" }
                }
            };
            schedulerTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var startTime = args?["start_time"]?.ToString() ?? DateTime.Now.ToString("yyyy-MM-dd HH:mm");
                var endTime = args?["end_time"]?.ToString() ?? DateTime.Now.AddHours(1).ToString("yyyy-MM-dd HH:mm");
                var taskName = args?["task_name"]?.ToString() ?? "Scheduled Task";
                
                switch (operation)
                {
                    case "schedule":
                        return Task.FromResult($"Task Scheduled:\nName: {taskName}\nStart: {startTime}\nEnd: {endTime}\nStatus: Pending");
                    case "calculate_duration":
                        if (DateTime.TryParse(startTime, out var start) && DateTime.TryParse(endTime, out var end))
                        {
                            var duration = end - start;
                            return Task.FromResult($"Duration Calculation:\nStart: {start:yyyy-MM-dd HH:mm}\nEnd: {end:yyyy-MM-dd HH:mm}\nDuration: {duration.TotalHours:F1} hours ({duration.Days} days, {duration.Hours} hours, {duration.Minutes} minutes)");
                        }
                        return Task.FromResult("Invalid time format");
                    case "business_days":
                        if (DateTime.TryParse(startTime, out var startDate) && DateTime.TryParse(endTime, out var endDate))
                        {
                            var businessDays = 0;
                            for (var date = startDate.Date; date <= endDate.Date; date = date.AddDays(1))
                            {
                                if (date.DayOfWeek != DayOfWeek.Saturday && date.DayOfWeek != DayOfWeek.Sunday)
                                    businessDays++;
                            }
                            return Task.FromResult($"Business Days: {businessDays} (excluding weekends)");
                        }
                        return Task.FromResult("Invalid date format");
                    case "time_zone":
                        var now = DateTime.Now;
                        return Task.FromResult($"Time Zone Info:\nLocal: {now:yyyy-MM-dd HH:mm}\nUTC: {now.ToUniversalTime():yyyy-MM-dd HH:mm}\nTimestamp: {((DateTimeOffset)now).ToUnixTimeSeconds()}");
                    default:
                        return Task.FromResult("Available operations: schedule, calculate_duration, business_days, time_zone");
                }
            };
            _tools[schedulerTool.Name] = schedulerTool;

            // 28. Data Validator Tool
            var validatorTool = new McpTool
            {
                Name = "data_validator",
                Description = "Data validation, schema checking, quality assessment",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: validate_email, validate_phone, validate_json, validate_format" },
                        data = new { type = "string", description = "Data to validate" },
                        format = new { type = "string", description = "Expected format" },
                        schema = new { type = "string", description = "JSON schema for validation" }
                    },
                    required = new[] { "operation", "data" }
                }
            };
            validatorTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var data = args?["data"]?.ToString() ?? "";
                var format = args?["format"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "validate_email":
                        var emailPattern = @"^[^@\s]+@[^@\s]+\.[^@\s]+$";
                        var isValidEmail = Regex.IsMatch(data, emailPattern);
                        return Task.FromResult($"Email Validation:\nEmail: {data}\nValid: {isValidEmail}");
                    case "validate_phone":
                        var phonePattern = @"^\+?[\d\s\-\(\)]{10,}$";
                        var isValidPhone = Regex.IsMatch(data, phonePattern);
                        return Task.FromResult($"Phone Validation:\nPhone: {data}\nValid: {isValidPhone}");
                    case "validate_json":
                        try
                        {
                            JObject.Parse(data);
                            return Task.FromResult($"JSON Validation:\nValid: true\nSize: {data.Length} characters");
                        }
                        catch (Exception ex)
                        {
                            return Task.FromResult($"JSON Validation:\nValid: false\nError: {ex.Message}");
                        }
                    case "validate_format":
                        bool matchesFormat;
                        switch (format)
                        {
                            case "date":
                                matchesFormat = DateTime.TryParse(data, out _);
                                break;
                            case "number":
                                matchesFormat = double.TryParse(data, out _);
                                break;
                            case "url":
                                matchesFormat = Uri.TryCreate(data, UriKind.Absolute, out _);
                                break;
                            default:
                                matchesFormat = false;
                                break;
                        }
                        return Task.FromResult($"Format Validation:\nData: {data}\nExpected: {format}\nValid: {matchesFormat}");
                    default:
                        return Task.FromResult("Available operations: validate_email, validate_phone, validate_json, validate_format");
                }
            };
            _tools[validatorTool.Name] = validatorTool;

            // 29. API Mocker Tool
            var apiTool = new McpTool
            {
                Name = "api_mocker",
                Description = "API response mocking, endpoint design, test data generation",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: mock_response, generate_data, design_endpoint" },
                        endpoint = new { type = "string", description = "API endpoint" },
                        method = new { type = "string", description = "HTTP method" },
                        data_type = new { type = "string", description = "Type of test data to generate" },
                        count = new { type = "number", description = "Number of records to generate" }
                    },
                    required = new[] { "operation" }
                }
            };
            apiTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var endpoint = args?["endpoint"]?.ToString() ?? "/api/users";
                var method = args?["method"]?.ToString()?.ToUpper() ?? "GET";
                var dataType = args?["data_type"]?.ToString() ?? "user";
                var count = Convert.ToInt32(args?["count"]?.ToString() ?? "3");
                
                switch (operation)
                {
                    case "mock_response":
                        var mockResponse = new
                        {
                            status = "success",
                            code = 200,
                            data = new[]
                            {
                                new { id = 1, name = "John Doe", email = "john@example.com" },
                                new { id = 2, name = "Jane Smith", email = "jane@example.com" }
                            },
                            timestamp = DateTime.Now.ToString("o")
                        };
                        return Task.FromResult($"Mock API Response for {method} {endpoint}:\n{JsonConvert.SerializeObject(mockResponse, Formatting.Indented)}");
                    case "generate_data":
                        var testData = new List<object>();
                        for (int i = 1; i <= count; i++)
                        {
                            object dataObject;
                            switch (dataType)
                            {
                                case "user":
                                    dataObject = new { id = i, name = $"User {i}", email = $"user{i}@example.com", age = 20 + i };
                                    break;
                                case "product":
                                    dataObject = new { id = i, name = $"Product {i}", price = i * 10.99, category = "Category A" };
                                    break;
                                default:
                                    dataObject = new { id = i, value = $"Data {i}" };
                                    break;
                            }
                            testData.Add(dataObject);
                        }
                        return Task.FromResult($"Generated {count} {dataType} records:\n{JsonConvert.SerializeObject(testData, Formatting.Indented)}");
                    case "design_endpoint":
                        var design = new
                        {
                            endpoint = endpoint,
                            method = method,
                            parameters = new[] { "id", "limit", "offset" },
                            response_format = new
                            {
                                status = "string",
                                data = "array|object",
                                message = "string",
                                timestamp = "iso8601"
                            },
                            status_codes = new[] { 200, 400, 404, 500 }
                        };
                        return Task.FromResult($"API Endpoint Design:\n{JsonConvert.SerializeObject(design, Formatting.Indented)}");
                    default:
                        return Task.FromResult("Available operations: mock_response, generate_data, design_endpoint");
                }
            };
            _tools[apiTool.Name] = apiTool;

            // 30. Performance Profiler Tool
            var profilerTool = new McpTool
            {
                Name = "performance_profiler",
                Description = "Performance measurement, benchmarking, optimization suggestions",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: benchmark, memory_usage, cpu_info, optimization" },
                        iterations = new { type = "number", description = "Number of iterations for benchmark" },
                        task_type = new { type = "string", description = "Type of task to benchmark" }
                    },
                    required = new[] { "operation" }
                }
            };
            profilerTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var iterations = Convert.ToInt32(args?["iterations"]?.ToString() ?? "1000");
                var taskType = args?["task_type"]?.ToString() ?? "string_operation";
                
                switch (operation)
                {
                    case "benchmark":
                        var stopwatch = Stopwatch.StartNew();
                        
                        // Simulate different benchmark types
                        for (int i = 0; i < iterations; i++)
                        {
                            if (taskType == "string_operation")
                            {
                                var str = $"test{i}";
                                str = str.ToUpper().ToLower();
                            }
                            else if (taskType == "math_operation")
                            {
                                var result = Math.Sqrt(i) * Math.PI;
                            }
                        }
                        
                        stopwatch.Stop();
                        var avgTime = stopwatch.ElapsedMilliseconds / (double)iterations;
                        
                        return Task.FromResult($"Benchmark Results:\nTask: {taskType}\nIterations: {iterations}\nTotal time: {stopwatch.ElapsedMilliseconds}ms\nAverage per operation: {avgTime:F4}ms\nOperations per second: {1000 / avgTime:F0}");
                    case "memory_usage":
                        var process = Process.GetCurrentProcess();
                        var workingSet = process.WorkingSet64 / 1024 / 1024;
                        var virtualMemory = process.VirtualMemorySize64 / 1024 / 1024;
                        var privateMemory = process.PrivateMemorySize64 / 1024 / 1024;
                        
                        return Task.FromResult($"Memory Usage:\nWorking Set: {workingSet} MB\nVirtual Memory: {virtualMemory} MB\nPrivate Memory: {privateMemory} MB\nGC Memory: {GC.GetTotalMemory(false) / 1024 / 1024} MB");
                    case "cpu_info":
                        return Task.FromResult($"CPU Information:\nProcessor Count: {Environment.ProcessorCount}\nCurrent Thread: {System.Threading.Thread.CurrentThread.ManagedThreadId}\nMachine Name: {Environment.MachineName}");
                    case "optimization":
                        return Task.FromResult($"Performance Optimization Suggestions:\n1. Use StringBuilder for string concatenation\n2. Cache frequently accessed data\n3. Use async/await for I/O operations\n4. Profile memory allocations\n5. Consider parallel processing for CPU-intensive tasks");
                    default:
                        return Task.FromResult("Available operations: benchmark, memory_usage, cpu_info, optimization");
                }
            };
            _tools[profilerTool.Name] = profilerTool;

            // 31. Config Manager Tool
            var configTool = new McpTool
            {
                Name = "config_manager",
                Description = "Configuration file management, environment variables, validation",
                InputSchema = new
                {
                    type = "object",
                    properties = new
                    {
                        operation = new { type = "string", description = "Operation: create_config, validate_config, env_vars, merge_configs" },
                        config_data = new { type = "string", description = "Configuration data (JSON)" },
                        config_name = new { type = "string", description = "Configuration name" },
                        env_var = new { type = "string", description = "Environment variable name" }
                    },
                    required = new[] { "operation" }
                }
            };
            configTool.ExecuteFunc = (args) =>
            {
                var operation = args?["operation"]?.ToString()?.ToLower();
                var configData = args?["config_data"]?.ToString() ?? "";
                var configName = args?["config_name"]?.ToString() ?? "app_config";
                var envVar = args?["env_var"]?.ToString() ?? "";
                
                switch (operation)
                {
                    case "create_config":
                        var defaultConfig = new
                        {
                            app_name = configName,
                            version = "1.0.0",
                            environment = "development",
                            database = new
                            {
                                host = "localhost",
                                port = 5432,
                                name = "myapp"
                            },
                            features = new
                            {
                                logging = true,
                                debug = true,
                                cache = false
                            },
                            created = DateTime.Now.ToString("o")
                        };
                        return Task.FromResult($"Generated Configuration '{configName}':\n{JsonConvert.SerializeObject(defaultConfig, Formatting.Indented)}");
                    case "validate_config":
                        try
                        {
                            var config = JObject.Parse(configData);
                            var hasRequired = config["app_name"] != null && config["version"] != null;
                            var structure = config.Properties().Select(p => p.Name);
                            
                            return Task.FromResult($"Config Validation:\nValid JSON: true\nHas required fields: {hasRequired}\nStructure: {string.Join(", ", structure)}\nSize: {configData.Length} characters");
                        }
                        catch (Exception ex)
                        {
                            return Task.FromResult($"Config Validation:\nValid: false\nError: {ex.Message}");
                        }
                    case "env_vars":
                        if (!string.IsNullOrEmpty(envVar))
                        {
                            var value = Environment.GetEnvironmentVariable(envVar);
                            return Task.FromResult($"Environment Variable:\n{envVar} = {value ?? "Not found"}");
                        }
                        else
                        {
                            var commonVars = new[] { "PATH", "USERNAME", "COMPUTERNAME", "OS" };
                            var vars = commonVars.Select(v => $"{v} = {Environment.GetEnvironmentVariable(v) ?? "Not found"}");
                            return Task.FromResult($"Common Environment Variables:\n{string.Join("\n", vars)}");
                        }
                    case "merge_configs":
                        var config1 = new { app = "MyApp", debug = true, port = 3000 };
                        var config2 = new { debug = false, ssl = true, timeout = 30 };
                        return Task.FromResult($"Config Merge Example:\nConfig 1: {JsonConvert.SerializeObject(config1)}\nConfig 2: {JsonConvert.SerializeObject(config2)}\nMerged: Combined configurations with Config 2 overriding conflicts");
                    default:
                        return Task.FromResult("Available operations: create_config, validate_config, env_vars, merge_configs");
                }
            };
            _tools[configTool.Name] = configTool;
        }

        private void InitializeResources()
        {
            // time://current resource (existing)
            var timeResource = new McpResource
            {
                Uri = "time://current",
                Name = "Current Time",
                Description = "Current date and time",
                MimeType = "text/plain"
            };
            timeResource.ReadFunc = async () => await Task.FromResult(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            _resources[timeResource.Uri] = timeResource;

            // datastore://summary resource (new)
            var datastoreResource = new McpResource
            {
                Uri = "datastore://summary",
                Name = "Data Store Summary",
                Description = "Summary of all stored data structures",
                MimeType = "application/json"
            };
            datastoreResource.ReadFunc = async () =>
            {
                var summary = new
                {
                    timestamp = DateTime.Now.ToString("o"),
                    dictionaries = new
                    {
                        count = _dictionaries.Count,
                        names = _dictionaries.Keys.ToArray(),
                        total_items = _dictionaries.Values.Sum(d => d.Count)
                    },
                    arrays = new
                    {
                        count = _arrays.Count,
                        names = _arrays.Keys.ToArray(),
                        total_items = _arrays.Values.Sum(a => a.Count)
                    },
                    tables = new
                    {
                        count = _tables.Count,
                        names = _tables.Keys.ToArray(),
                        total_rows = _tables.Values.Sum(t => t.Count)
                    },
                    graphs = new
                    {
                        count = _graphs.Count,
                        names = _graphs.Keys.ToArray(),
                        total_nodes = _graphs.Values.Sum(g => g.Count),
                        total_edges = _graphs.Values.Sum(g => g.Values.Sum(edges => edges.Count))
                    },
                    statistics = new
                    {
                        total_data_structures = _dictionaries.Count + _arrays.Count + _tables.Count + _graphs.Count,
                        memory_usage = $"{GC.GetTotalMemory(false) / 1024 / 1024} MB"
                    }
                };

                return await Task.FromResult(JsonConvert.SerializeObject(summary, Formatting.Indented));
            };
            _resources[datastoreResource.Uri] = datastoreResource;
        }

        private string CreateSuccessResponse(object id, object result)
        {
            var response = new JsonRpcResponse
            {
                Id = id,
                Result = result
            };
            return JsonConvert.SerializeObject(response);
        }

        private string CreateErrorResponse(object id, int code, string message)
        {
            var response = new JsonRpcResponse
            {
                Id = id,
                Error = new JsonRpcError
                {
                    Code = code,
                    Message = message
                }
            };
            return JsonConvert.SerializeObject(response);
        }
    }

    public class McpTool
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public object InputSchema { get; set; }
        public Func<JObject, Task<string>> ExecuteFunc { get; set; }

        public async Task<string> ExecuteAsync(JObject arguments)
        {
            return await ExecuteFunc(arguments);
        }
    }

    public class McpResource
    {
        public string Uri { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string MimeType { get; set; }
        public Func<Task<string>> ReadFunc { get; set; }

        public async Task<string> ReadAsync()
        {
            return await ReadFunc();
        }
    }
}