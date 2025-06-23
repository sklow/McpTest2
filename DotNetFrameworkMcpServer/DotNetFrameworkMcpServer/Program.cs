using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using log4net;
using log4net.Config;

namespace DotNetFrameworkMcpServer
{
    internal class Program
    {
        public static void Main(string[] args)
        {
            MainAsync(args).GetAwaiter().GetResult();
        }

        private static async Task MainAsync(string[] args)
        {
            // Initialize log4net
            var logRepository = LogManager.GetRepository(System.Reflection.Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new FileInfo("log4net.config"));

            var mcpServer = new McpServer();
            
            // Parse command line arguments
            var useHttp = false;
            var host = "localhost";
            var port = 8080;
            var path = "/mcp";
            
            for (int i = 0; i < args.Length; i++)
            {
                switch (args[i].ToLower())
                {
                    case "--transport":
                    case "-t":
                        if (i + 1 < args.Length && args[i + 1].ToLower() == "http")
                        {
                            useHttp = true;
                        }
                        i++;
                        break;
                    case "--host":
                    case "-h":
                        if (i + 1 < args.Length)
                        {
                            host = args[i + 1];
                        }
                        i++;
                        break;
                    case "--port":
                    case "-p":
                        if (i + 1 < args.Length && int.TryParse(args[i + 1], out var parsedPort))
                        {
                            port = parsedPort;
                        }
                        i++;
                        break;
                    case "--path":
                        if (i + 1 < args.Length)
                        {
                            path = args[i + 1];
                        }
                        i++;
                        break;
                    case "--help":
                        ShowHelp();
                        return;
                }
            }

            if (useHttp)
            {
                // Use HTTP transport
                var httpServer = new StreamableHttpServer(mcpServer, host, port, path);
                
                Console.CancelKeyPress += (sender, e) =>
                {
                    e.Cancel = true;
                    httpServer.Stop();
                };

                try
                {
                    Console.WriteLine($"Starting MCP server with HTTP transport on http://{host}:{port}{path}");
                    await httpServer.StartAsync();
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"HTTP Server error: {ex.Message}");
                }
            }
            else
            {
                // Use STDIO transport (default)
                var stdioServer = new StdioServer(mcpServer);
                
                Console.CancelKeyPress += (sender, e) =>
                {
                    e.Cancel = true;
                    stdioServer.Stop();
                };

                try
                {
                    await stdioServer.StartAsync();
                }
                catch (Exception ex)
                {
                    // Log to stderr to avoid interfering with STDIO communication
                    Console.Error.WriteLine($"STDIO Server error: {ex.Message}");
                }
            }
        }
        
        private static void ShowHelp()
        {
            Console.WriteLine("MCP Server - Model Context Protocol Server");
            Console.WriteLine();
            Console.WriteLine("Usage:");
            Console.WriteLine("  DotNetFrameworkMcpServer.exe [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  -t, --transport <type>    Transport type: stdio (default) or http");
            Console.WriteLine("  -h, --host <host>         HTTP host (default: localhost, only for HTTP transport)");
            Console.WriteLine("  -p, --port <port>         HTTP port (default: 8080, only for HTTP transport)");
            Console.WriteLine("      --path <path>         HTTP endpoint path (default: /mcp, only for HTTP transport)");
            Console.WriteLine("      --help                Show this help message");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  DotNetFrameworkMcpServer.exe                           # STDIO transport (default)");
            Console.WriteLine("  DotNetFrameworkMcpServer.exe -t http                   # HTTP transport on localhost:8080");
            Console.WriteLine("  DotNetFrameworkMcpServer.exe -t http -p 9000           # HTTP transport on port 9000");
            Console.WriteLine("  DotNetFrameworkMcpServer.exe -t http -h 0.0.0.0 -p 8080 # HTTP transport on all interfaces");
        }
    }
}