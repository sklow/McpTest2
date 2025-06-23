using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using log4net;
using Newtonsoft.Json;

namespace DotNetFrameworkMcpServer
{
    public class StreamableHttpServer
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(StreamableHttpServer));
        
        private readonly McpServer _mcpServer;
        private readonly HttpListener _httpListener;
        private readonly ConcurrentDictionary<string, SseConnection> _connections;
        private CancellationTokenSource _cancellationTokenSource;
        private readonly string _host;
        private readonly int _port;
        private readonly string _path;
        private long _eventIdCounter = 0;

        public StreamableHttpServer(McpServer mcpServer, string host = "localhost", int port = 8080, string path = "/mcp")
        {
            _mcpServer = mcpServer;
            _host = host;
            _port = port;
            _path = path;
            _httpListener = new HttpListener();
            _connections = new ConcurrentDictionary<string, SseConnection>();
        }

        public async Task StartAsync()
        {
            _cancellationTokenSource = new CancellationTokenSource();
            
            try
            {
                var prefix = $"http://{_host}:{_port}{_path}/";
                _httpListener.Prefixes.Add(prefix);
                _httpListener.Start();
                
                Log.Info($"Streamable HTTP server started on {prefix}");
                
                // Handle incoming requests
                await HandleRequestsAsync(_cancellationTokenSource.Token);
            }
            catch (Exception ex)
            {
                Log.Error($"Error starting HTTP server: {ex.Message}", ex);
                throw;
            }
        }

        public void Stop()
        {
            try
            {
                _cancellationTokenSource?.Cancel();
                
                // Close all SSE connections
                foreach (var connection in _connections.Values)
                {
                    connection.Close();
                }
                _connections.Clear();
                
                _httpListener?.Stop();
                _httpListener?.Close();
                
                Log.Info("Streamable HTTP server stopped");
            }
            catch (Exception ex)
            {
                Log.Error($"Error stopping HTTP server: {ex.Message}", ex);
            }
        }

        private async Task HandleRequestsAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    var context = await _httpListener.GetContextAsync();
                    
                    // Handle request in background
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await HandleHttpRequestAsync(context, cancellationToken);
                        }
                        catch (Exception ex)
                        {
                            Log.Error($"Error handling HTTP request: {ex.Message}", ex);
                        }
                    }, cancellationToken);
                }
                catch (ObjectDisposedException)
                {
                    // Listener was stopped
                    break;
                }
                catch (HttpListenerException ex) when (ex.ErrorCode == 995) // ERROR_OPERATION_ABORTED
                {
                    // Listener was stopped
                    break;
                }
                catch (Exception ex)
                {
                    Log.Error($"Error in request handling loop: {ex.Message}", ex);
                }
            }
        }

        private async Task HandleHttpRequestAsync(HttpListenerContext context, CancellationToken cancellationToken)
        {
            var request = context.Request;
            var response = context.Response;
            
            try
            {
                // Validate Origin header for security
                var origin = request.Headers["Origin"];
                if (!string.IsNullOrEmpty(origin) && !IsAllowedOrigin(origin))
                {
                    response.StatusCode = 403;
                    response.Close();
                    return;
                }

                // Handle CORS preflight
                if (request.HttpMethod == "OPTIONS")
                {
                    HandleCorsPreflightRequest(response);
                    return;
                }

                // Add CORS headers
                AddCorsHeaders(response);

                if (request.HttpMethod == "POST")
                {
                    await HandlePostRequestAsync(request, response, cancellationToken);
                }
                else if (request.HttpMethod == "GET")
                {
                    await HandleGetRequestAsync(request, response, cancellationToken);
                }
                else
                {
                    response.StatusCode = 405; // Method Not Allowed
                    response.Close();
                }
            }
            catch (Exception ex)
            {
                Log.Error($"Error handling HTTP request: {ex.Message}", ex);
                
                if (!response.OutputStream.CanWrite)
                    return;
                    
                response.StatusCode = 500;
                response.Close();
            }
        }

        private async Task HandlePostRequestAsync(HttpListenerRequest request, HttpListenerResponse response, CancellationToken cancellationToken)
        {
            // Read request body
            string requestBody;
            using (var reader = new StreamReader(request.InputStream, Encoding.UTF8))
            {
                requestBody = await reader.ReadToEndAsync();
            }

            if (string.IsNullOrWhiteSpace(requestBody))
            {
                response.StatusCode = 400;
                response.Close();
                return;
            }

            // Get session ID
            var sessionId = request.Headers["Mcp-Session-Id"];

            // Process MCP message
            var mcpResponse = await _mcpServer.HandleMessageAsync(requestBody);
            
            // Check if client accepts SSE
            var acceptHeader = request.Headers["Accept"];
            var acceptsEventStream = !string.IsNullOrEmpty(acceptHeader) && 
                                   acceptHeader.Contains("text/event-stream");

            if (acceptsEventStream && IsJsonRpcRequest(requestBody))
            {
                // Start SSE stream for requests
                await StartSseStreamAsync(response, mcpResponse, sessionId, cancellationToken);
            }
            else
            {
                // Send JSON response for notifications/responses
                response.StatusCode = 202; // Accepted
                response.ContentType = "application/json";
                
                if (!string.IsNullOrEmpty(mcpResponse))
                {
                    var responseBytes = Encoding.UTF8.GetBytes(mcpResponse);
                    response.ContentLength64 = responseBytes.Length;
                    await response.OutputStream.WriteAsync(responseBytes, 0, responseBytes.Length);
                }
                
                response.Close();
            }
        }

        private async Task HandleGetRequestAsync(HttpListenerRequest request, HttpListenerResponse response, CancellationToken cancellationToken)
        {
            // Handle SSE connection resumption
            var lastEventId = request.Headers["Last-Event-ID"];
            var sessionId = request.Headers["Mcp-Session-Id"];
            
            await StartSseStreamAsync(response, null, sessionId, cancellationToken, lastEventId);
        }

        private async Task StartSseStreamAsync(HttpListenerResponse response, string initialMessage, string sessionId, CancellationToken cancellationToken, string lastEventId = null)
        {
            // Setup SSE response
            response.StatusCode = 200;
            response.ContentType = "text/event-stream";
            response.Headers["Cache-Control"] = "no-cache";
            response.Headers["Connection"] = "keep-alive";
            
            // Add session ID if not provided
            if (string.IsNullOrEmpty(sessionId))
            {
                sessionId = Guid.NewGuid().ToString();
                response.Headers["Mcp-Session-Id"] = sessionId;
            }

            var connection = new SseConnection(response.OutputStream, sessionId);
            _connections[sessionId] = connection;

            try
            {
                // Send initial message if provided
                if (!string.IsNullOrEmpty(initialMessage))
                {
                    await connection.SendEventAsync("message", initialMessage, GetNextEventId());
                }

                // Keep connection alive
                await connection.KeepAliveAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                Log.Error($"Error in SSE stream: {ex.Message}", ex);
            }
            finally
            {
                _connections.TryRemove(sessionId, out _);
                connection?.Close();
            }
        }

        private bool IsJsonRpcRequest(string json)
        {
            try
            {
                var obj = JsonConvert.DeserializeObject<JsonRpcRequest>(json);
                return obj?.Id != null; // Requests have ID, notifications don't
            }
            catch
            {
                return false;
            }
        }

        private bool IsAllowedOrigin(string origin)
        {
            // For localhost servers, be more permissive
            if (_host == "localhost" || _host == "127.0.0.1")
            {
                return origin.StartsWith("http://localhost") || 
                       origin.StartsWith("http://127.0.0.1") ||
                       origin.StartsWith("https://localhost") ||
                       origin.StartsWith("https://127.0.0.1");
            }
            
            // Add more specific origin validation as needed
            return true;
        }

        private void HandleCorsPreflightRequest(HttpListenerResponse response)
        {
            AddCorsHeaders(response);
            response.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
            response.Headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Origin, Mcp-Session-Id, Last-Event-ID";
            response.StatusCode = 200;
            response.Close();
        }

        private void AddCorsHeaders(HttpListenerResponse response)
        {
            response.Headers["Access-Control-Allow-Origin"] = "*";
            response.Headers["Access-Control-Allow-Credentials"] = "false";
        }

        private string GetNextEventId()
        {
            return Interlocked.Increment(ref _eventIdCounter).ToString();
        }

        public async Task SendServerMessageAsync(string sessionId, string message)
        {
            if (_connections.TryGetValue(sessionId, out var connection))
            {
                await connection.SendEventAsync("message", message, GetNextEventId());
            }
        }
    }

    public class SseConnection
    {
        private readonly Stream _outputStream;
        private readonly string _sessionId;
        private readonly StreamWriter _writer;
        private volatile bool _isOpen = true;

        public SseConnection(Stream outputStream, string sessionId)
        {
            _outputStream = outputStream;
            _sessionId = sessionId;
            _writer = new StreamWriter(outputStream, Encoding.UTF8);
            _writer.AutoFlush = true;
        }

        public async Task SendEventAsync(string eventType, string data, string eventId = null)
        {
            if (!_isOpen) return;

            try
            {
                if (!string.IsNullOrEmpty(eventId))
                {
                    await _writer.WriteLineAsync($"id: {eventId}");
                }
                
                await _writer.WriteLineAsync($"event: {eventType}");
                
                // Handle multi-line data
                var lines = data.Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var line in lines)
                {
                    await _writer.WriteLineAsync($"data: {line}");
                }
                
                await _writer.WriteLineAsync(); // Empty line to end the event
            }
            catch (Exception ex)
            {
                Log.Error($"Error sending SSE event: {ex.Message}", ex);
                _isOpen = false;
            }
        }

        public async Task KeepAliveAsync(CancellationToken cancellationToken)
        {
            try
            {
                while (_isOpen && !cancellationToken.IsCancellationRequested)
                {
                    await Task.Delay(30000, cancellationToken); // Send keep-alive every 30 seconds
                    
                    if (_isOpen)
                    {
                        await SendEventAsync("ping", "keep-alive");
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Expected when cancelled
            }
            catch (Exception ex)
            {
                Log.Error($"Error in keep-alive: {ex.Message}", ex);
            }
        }

        public void Close()
        {
            _isOpen = false;
            try
            {
                _writer?.Dispose();
                _outputStream?.Close();
            }
            catch (Exception ex)
            {
                Log.Error($"Error closing SSE connection: {ex.Message}", ex);
            }
        }

        private static readonly ILog Log = LogManager.GetLogger(typeof(SseConnection));
    }
}