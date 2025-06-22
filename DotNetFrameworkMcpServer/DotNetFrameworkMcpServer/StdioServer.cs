using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using log4net;

namespace DotNetFrameworkMcpServer
{
    public class StdioServer
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(StdioServer));
        
        private readonly McpServer _mcpServer;
        private CancellationTokenSource _cancellationTokenSource;

        public StdioServer(McpServer mcpServer)
        {
            _mcpServer = mcpServer;
        }

        public async Task StartAsync()
        {
            _cancellationTokenSource = new CancellationTokenSource();
            
            try
            {
                using (var stdin = new StreamReader(Console.OpenStandardInput(), new UTF8Encoding(false)))
                using (var stdout = new StreamWriter(Console.OpenStandardOutput(), new UTF8Encoding(false)))
                {
                    stdout.AutoFlush = true;
                    
                    await HandleStdioAsync(stdin, stdout, _cancellationTokenSource.Token);
                }
            }
            catch (Exception ex)
            {
                Log.Error($"Error in STDIO server: {ex.Message}", ex);
            }
        }

        public void Stop()
        {
            _cancellationTokenSource?.Cancel();
        }

        private async Task HandleStdioAsync(StreamReader stdin, StreamWriter stdout, CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    var line = await ReadLineAsync(stdin, cancellationToken);
                    if (line == null) 
                    {
                        // EOF reached
                        break;
                    }

                    if (!string.IsNullOrWhiteSpace(line))
                    {
                        var response = await _mcpServer.HandleMessageAsync(line);
                        if (response != null && !string.IsNullOrEmpty(response))
                        {
                            await stdout.WriteLineAsync(response);
                        }
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Log.Error($"Error processing STDIO message: {ex.Message}", ex);
                }
            }
        }

        private async Task<string> ReadLineAsync(StreamReader reader, CancellationToken cancellationToken)
        {
            try
            {
                // Use proper async ReadLine for better performance
                var readTask = reader.ReadLineAsync();
                var cancellationTask = Task.Delay(-1, cancellationToken);
                
                var completedTask = await Task.WhenAny(readTask, cancellationTask);
                
                if (completedTask == readTask)
                {
                    return await readTask;
                }
                else
                {
                    return null; // Cancelled
                }
            }
            catch (OperationCanceledException)
            {
                return null;
            }
        }
    }
}