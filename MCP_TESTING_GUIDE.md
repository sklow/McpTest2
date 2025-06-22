# MCP Testing Guide

このガイドでは、DotNetFrameworkMcpServer の MCP ツールをテストする方法を説明します。

## 前提条件

- .NET Framework 4.8.1 以降
- Node.js と npm
- プロジェクトがビルド済み（Release モード推奨）

## テストスクリプト

### 基本テストスクリプト（既存）

**基本的な MCP Inspector の起動:**
- `test-mcp-inspector.bat` (Windows)
- `test-mcp-inspector.sh` (Linux/WSL)
- `test-mcp-inspector.ps1` (PowerShell)

### 詳細テストスクリプト（新規）

**包括的なツールテスト機能:**
- `test-mcp-tools.bat` (Windows)
- `test-mcp-tools.sh` (Linux/WSL)

## 使用方法

### 1. 基本的な使い方

**Linux/WSL:**
```bash
./test-mcp-tools.sh [COMMAND] [OPTIONS]
```

**Windows:**
```cmd
test-mcp-tools.bat [COMMAND] [OPTIONS]
```

### 2. 利用可能なコマンド

| コマンド | 説明 |
|---------|------|
| `check` | 前提条件をチェック |
| `connectivity` | サーバー接続をテスト |
| `list-tools` | 利用可能なツール一覧を表示 |
| `list-resources` | 利用可能なリソース一覧を表示 |
| `call-tool TOOL` | 特定のツールを引数付きで呼び出し |
| `read-resource URI` | 特定のリソースを読み取り |
| `test-all` | 全ツールの定義済みテストを実行 |
| `start-http` | HTTP/SSE サーバーを起動 |
| `test-http` | HTTP/SSE テストの説明を表示 |
| `help` | ヘルプメッセージを表示 |

## テスト例

### ツール一覧の取得

```bash
# 利用可能なツール一覧を表示
./test-mcp-tools.sh list-tools

# 利用可能なリソース一覧を表示
./test-mcp-tools.sh list-resources
```

### 個別ツールのテスト

#### 基本ツール

```bash
# echo ツール - メッセージをエコー
./test-mcp-tools.sh call-tool echo --arg message="Hello World"

# システム情報取得
./test-mcp-tools.sh call-tool system_info --arg info_type=os
./test-mcp-tools.sh call-tool system_info --arg info_type=memory
./test-mcp-tools.sh call-tool system_info --arg info_type=cpu
./test-mcp-tools.sh call-tool system_info --arg info_type=processes
```

#### ユニークなツール

```bash
# 見せ算（さや香の五則演算）
./test-mcp-tools.sh call-tool misezan --arg num1=6 --arg num2=9
./test-mcp-tools.sh call-tool misezan --arg num1=5 --arg num2=5

# 遅延レスポンス（リアルタイム処理）
./test-mcp-tools.sh call-tool delay_response --arg seconds=3 --arg message="3秒遅延テスト"

# パスワード生成
./test-mcp-tools.sh call-tool password_generator --arg length=16 --arg include_symbols=true
./test-mcp-tools.sh call-tool password_generator --arg length=20 --arg include_symbols=false
```

#### ファイル操作

```bash
# ファイル作成
./test-mcp-tools.sh call-tool file_operations --arg operation=create --arg filename=test.txt --arg content="テストファイルの内容"

# ファイル読み取り
./test-mcp-tools.sh call-tool file_operations --arg operation=read --arg filename=test.txt

# ファイル一覧
./test-mcp-tools.sh call-tool file_operations --arg operation=list

# ファイル削除
./test-mcp-tools.sh call-tool file_operations --arg operation=delete --arg filename=test.txt
```

#### ネットワーク・セキュリティ

```bash
# ネットワーク ping
./test-mcp-tools.sh call-tool network_ping --arg hostname=google.com --arg count=3
./test-mcp-tools.sh call-tool network_ping --arg hostname=example.com --arg count=5

# AES 暗号化
./test-mcp-tools.sh call-tool encryption --arg operation=encrypt --arg text="秘密のメッセージ" --arg password="mypassword"

# AES 復号化（暗号化で取得した結果を使用）
./test-mcp-tools.sh call-tool encryption --arg operation=decrypt --arg text="[暗号化された文字列]" --arg password="mypassword"
```

#### エンタメ・ユーティリティ

```bash
# QR コード生成（ASCII）
./test-mcp-tools.sh call-tool qr_generator --arg text="https://example.com" --arg size=25

# 運勢占い
./test-mcp-tools.sh call-tool fortune_teller --arg name="太郎" --arg category=general
./test-mcp-tools.sh call-tool fortune_teller --arg name="花子" --arg category=love
./test-mcp-tools.sh call-tool fortune_teller --arg name="次郎" --arg category=money

# メモリ使用量監視（リアルタイム）
./test-mcp-tools.sh call-tool memory_monitor --arg duration=10
```

### リソースの読み取り

```bash
# 現在時刻リソース
./test-mcp-tools.sh read-resource "time://current"
```

### 一括テスト

```bash
# 全ツールの定義済みテストを実行
./test-mcp-tools.sh test-all
```

## HTTP/SSE サーバーテスト

### 1. HTTP サーバーの起動

**ターミナル 1:**
```bash
# HTTP/SSE モードでサーバーを起動
./test-mcp-tools.sh start-http
```

サーバーは `http://localhost:41114` で利用可能になります。

### 2. HTTP エンドポイントのテスト

**ターミナル 2:**
```bash
# ツール一覧取得
npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/list

# リソース一覧取得
npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method resources/list

# ツール呼び出し例
npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/call --tool-name echo --tool-arg message="HTTP経由のテスト"

npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/call --tool-name system_info --tool-arg info_type=os

npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method tools/call --tool-name misezan --tool-arg num1=7 --tool-arg num2=3

# リソース読み取り
npx @modelcontextprotocol/inspector --cli http://localhost:41114/sse --method resources/read --resource-uri "time://current"
```

## 利用可能なツール一覧

| ツール名 | 説明 | 主要パラメータ |
|---------|------|---------------|
| `echo` | メッセージをエコー | `message` (string) |
| `misezan` | さや香の見せ算（五則演算） | `num1`, `num2` (0-9の整数) |
| `delay_response` | 指定秒数後にレスポンス | `seconds` (1-60), `message` (string) |
| `system_info` | システム情報取得 | `info_type` (os/memory/cpu/processes) |
| `file_operations` | ファイル操作 | `operation` (create/read/delete/list), `filename`, `content` |
| `network_ping` | ネットワーク疎通確認 | `hostname` (string), `count` (1-10) |
| `encryption` | AES暗号化・復号化 | `operation` (encrypt/decrypt), `text`, `password` |
| `password_generator` | セキュアパスワード生成 | `length` (8-128), `include_symbols` (bool) |
| `qr_generator` | QRコード生成（ASCII） | `text` (string), `size` (10-50) |
| `fortune_teller` | 時間基準運勢占い | `name` (string), `category` (love/money/health/work/general) |
| `memory_monitor` | リアルタイムメモリ監視 | `duration` (1-30秒) |

## 利用可能なリソース一覧

| リソース URI | 説明 | MIME タイプ |
|-------------|------|-------------|
| `time://current` | 現在の日付と時刻 | `text/plain` |

## トラブルシューティング

### よくある問題

1. **実行ファイルが見つからない**
   ```bash
   # プロジェクトをビルド
   dotnet build DotNetFrameworkMcpServer.sln -c Release
   ```

2. **MCP Inspector がインストールされていない**
   ```bash
   # グローバルインストール
   npm install -g @modelcontextprotocol/inspector
   ```

3. **ポートが使用中**
   - TCP: 41113
   - HTTP: 41114
   
   これらのポートが他のプロセスで使用されていないか確認してください。

### デバッグ情報

- サーバーログは log4net.config の設定に従って出力されます
- ツールの実行結果は JSON 形式で返されます
- エラーが発生した場合は JSON-RPC エラーレスポンスが返されます

## 開発者向け情報

### 新しいツールの追加

1. `McpServer.cs` の `InitializeDefaultToolsAndResources()` メソッドでツールを登録
2. JSON スキーマを定義
3. 実行関数を実装
4. テストケースを追加

### カスタムテストの追加

`test-mcp-tools.sh` の `run_tests()` 関数に新しいテストケースを追加できます。

---

このガイドを使用して、DotNetFrameworkMcpServer の全機能を包括的にテストできます。