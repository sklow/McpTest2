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
                Console.Error.WriteLine($"Server error: {ex.Message}");
            }
        }
    }
}