# .NET Framework MCPサーバー

.NET Framework 4.8.1でSTDIO通信を使用するModel Context Protocol (MCP) サーバーの実装です。

## 概要

このMCPサーバーは、Claude DesktopとNET Frameworkアプリケーション間のブリッジを提供します。STDIO（標準入出力）トランスポートを使用してJSON-RPC 2.0でMCP仕様を実装しています。

## 機能

- **STDIOトランスポート**: 標準入出力を使用した直接通信
- **JSON-RPC 2.0**: 完全なJSON-RPC 2.0プロトコル実装
- **ツールサポート**: Claude Desktopからカスタムツールの実行
- **リソースサポート**: カスタムリソースへのアクセスと読み取り
- **31個の組み込みツール**: システムアクセス、データ処理、暗号化などの多様なツール

## 前提条件

- .NET Framework 4.8.1以降
- Windows オペレーティングシステム
- Claude Desktop アプリケーション

## サーバーのビルド

1. このリポジトリをクローンまたはダウンロード
2. Visual Studioでソリューションを開くか、MSBuildを使用:
   ```cmd
   msbuild DotNetFrameworkMcpServer.sln /p:Configuration=Release
   ```
3. 実行ファイルは `DotNetFrameworkMcpServer\bin\Release\` に作成されます

## サーバーの実行

### コマンドライン
```cmd
cd DotNetFrameworkMcpServer\bin\Release
DotNetFrameworkMcpServer.exe
```

サーバーが開始され、STDIO（標準入出力）モードで動作します。

### バックグラウンドサービスとして
本番環境では、サーバーをWindowsサービスとして実行するか、プロセスマネージャーの使用を検討してください。

## Claude Desktop設定

このMCPサーバーをClaude Desktopで使用するには、Claude Desktopの設定に以下の設定を追加してください:

### Windows
設定ファイルを編集:
```
%APPDATA%\Claude\claude_desktop_config.json
```

MCPサーバー設定を追加:
```json
{
  "mcpServers": {
    "dotnet-framework-mcp": {
      "command": "C:\\path\\to\\your\\DotNetFrameworkMcpServer.exe"
    }
  }
}
```

**注意**: このサーバーはSTDIOトランスポートを使用するため、Claude Desktopと直接通信できます。TCPトランスポートは使用していません。

## 利用可能なツール

### エコーツール
- **名前**: `echo`
- **説明**: 提供されたメッセージをエコーバック
- **パラメータ**:
  - `message` (文字列、必須): エコーするメッセージ

**Claude Desktopでの使用例**:
```
エコーツールを使って「Hello World」と言ってください
```

## 利用可能なリソース

### 現在時刻リソース
- **URI**: `time://current`
- **名前**: 現在時刻
- **説明**: 現在の日付と時刻を提供
- **MIMEタイプ**: `text/plain`

## カスタムツールとリソースの追加

### 新しいツールの追加

1. `McpServer.cs`を開く
2. `InitializeDefaultToolsAndResources()`メソッドで、ツールを追加:

```csharp
var myTool = new McpTool
{
    Name = "my_tool",
    Description = "マイカスタムツール",
    InputSchema = new
    {
        type = "object",
        properties = new
        {
            param1 = new
            {
                type = "string",
                description = "最初のパラメータ"
            }
        },
        required = new[] { "param1" }
    }
};

myTool.ExecuteFunc = async (args) =>
{
    var param1 = args?["param1"]?.ToString();
    // ツールのロジックをここに記述
    return $"結果: {param1}";
};

_tools[myTool.Name] = myTool;
```

### 新しいリソースの追加

```csharp
var myResource = new McpResource
{
    Uri = "my://resource",
    Name = "マイリソース",
    Description = "マイカスタムリソース",
    MimeType = "text/plain"
};

myResource.ReadFunc = async () =>
{
    // リソース読み取りロジックをここに記述
    return "リソースコンテンツ";
};

_resources[myResource.Uri] = myResource;
```

## プロトコルサポート

このサーバーは以下のMCPメソッドを実装しています:

- `initialize` - 機能でサーバーを初期化
- `initialized` - 初期化を確認
- `tools/list` - 利用可能なツールを一覧表示
- `tools/call` - ツールを実行
- `resources/list` - 利用可能なリソースを一覧表示
- `resources/read` - リソースを読み取り

## トラブルシューティング

### STDIO通信の問題
- Claude Desktopが正しいサーバーパスで設定されていることを確認
- サーバーの実行ファイルに適切なアクセス権限があることを確認
- ログファイル（log4net.config）の設定を確認

### JSON-RPCエラー
サーバーはエラーをコンソールにログ出力します。よくある問題:
- 無効なJSON形式
- 必須パラメータの不足
- ツール実行の失敗

## 開発

### プロジェクト構造
- `Program.cs` - アプリケーションエントリポイントとサーバー起動
- `McpServer.cs` - メインMCPプロトコル実装
- `StdioServer.cs` - STDIOトランスポート層
- `HttpSseServer.cs` - HTTP/SSE トランスポート層（未使用）
- `JsonRpcMessage.cs` - JSON-RPCメッセージタイプ

### テスト
STDIOモードでサーバーをテストするためのテストスクリプトが用意されています:

- `quick-test.bat` - 包括的な機能テスト
- `test-mcp-simple.bat` - 特定のコマンドのテスト
- `test-mcp-en.bat` - 英語でのテスト
- `test-mcp-jp.bat` - 日本語でのテスト

例:
```cmd
test-mcp-simple.bat list-tools
```

## ライセンス

このプロジェクトは教育および開発目的でそのまま提供されています。