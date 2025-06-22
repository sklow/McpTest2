# MCP サーバーテストスクリプト（PowerShell版）
param(
    [string]$Command = "help"
)

# UTF-8 エンコーディングを設定
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MCP サーバーテスト（PowerShell版）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host

# 実行ファイルの存在確認
$ExePath = "DotNetFrameworkMcpServer\bin\Release\DotNetFrameworkMcpServer.exe"
if (-not (Test-Path $ExePath)) {
    Write-Host "エラー: $ExePath が見つかりません！" -ForegroundColor Red
    Write-Host "最初にプロジェクトをビルドしてください：" -ForegroundColor Yellow
    Write-Host "  dotnet build DotNetFrameworkMcpServer.sln -c Release" -ForegroundColor Yellow
    Write-Host
    Read-Host "Enterキーを押して終了"
    return
}

Write-Host "実行ファイルを発見: $ExePath" -ForegroundColor Green
Write-Host

function Invoke-MCPCommand {
    param([string]$JsonInput, [string]$Title)
    
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # 一時ファイルに JSON を書き込み
    $TempFile = [System.IO.Path]::GetTempFileName()
    $JsonInput | Out-File -FilePath $TempFile -Encoding UTF8
    
    # MCP サーバーを実行
    $Result = Get-Content $TempFile | & $ExePath
    
    # 一時ファイルを削除
    Remove-Item $TempFile
    
    return $Result
}

function Show-ToolsList {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "利用可能なツール一覧"
    
    Write-Host
    Write-Host "ツール名一覧:" -ForegroundColor Green
    Write-Host "-------------" -ForegroundColor Green
    
    # ツール名を抽出
    $ToolNames = $Result | Where-Object { $_ -match '"name":\s*"([^"]+)"' } | ForEach-Object {
        if ($_ -match '"name":\s*"([^"]+)"') {
            "  ★ $($Matches[1])"
        }
    }
    
    $ToolNames | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
    
    # ツール数を表示
    $ToolCount = ($ToolNames | Measure-Object).Count
    Write-Host
    Write-Host "合計 $ToolCount 個のツールが見つかりました。" -ForegroundColor Green
    
    Write-Host
    Write-Host "完全なJSONレスポンス:" -ForegroundColor Yellow
    Write-Host "--------------------" -ForegroundColor Yellow
    $Result | ForEach-Object { Write-Host $_ }
}

function Show-ResourcesList {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "利用可能なリソース一覧"
    
    Write-Host
    Write-Host "リソースURI一覧:" -ForegroundColor Green
    Write-Host "----------------" -ForegroundColor Green
    
    # リソースURIを抽出
    $ResourceURIs = $Result | Where-Object { $_ -match '"uri":\s*"([^"]+)"' } | ForEach-Object {
        if ($_ -match '"uri":\s*"([^"]+)"') {
            "  ★ $($Matches[1])"
        }
    }
    
    $ResourceURIs | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
    
    Write-Host
    Write-Host "完全なJSONレスポンス:" -ForegroundColor Yellow
    Write-Host "--------------------" -ForegroundColor Yellow
    $Result | ForEach-Object { Write-Host $_ }
}

function Test-EchoTool {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"こんにちは、MCPテストです！"}}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "エコーツールテスト結果"
    
    Write-Host
    Write-Host "レスポンス:" -ForegroundColor Green
    Write-Host "-----------" -ForegroundColor Green
    $Result | ForEach-Object { Write-Host $_ }
}

function Test-SystemTool {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"system_info","arguments":{"info_type":"os"}}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "システム情報ツールテスト結果"
    
    Write-Host
    Write-Host "レスポンス:" -ForegroundColor Green
    Write-Host "-----------" -ForegroundColor Green
    $Result | ForEach-Object { Write-Host $_ }
}

function Test-JsonTool {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"json_manipulator","arguments":{"operation":"validate","json_data":"{\"name\":\"テスト\",\"value\":123}"}}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "JSONツールテスト結果"
    
    Write-Host
    Write-Host "レスポンス:" -ForegroundColor Green
    Write-Host "-----------" -ForegroundColor Green
    $Result | ForEach-Object { Write-Host $_ }
}

function Test-ArrayTool {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"array_operations","arguments":{"operation":"create","array_id":"test_array","data":"[\"apple\",\"banana\",\"cherry\"]"}}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "配列操作ツールテスト結果"
    
    Write-Host
    Write-Host "レスポンス:" -ForegroundColor Green
    Write-Host "-----------" -ForegroundColor Green
    $Result | ForEach-Object { Write-Host $_ }
}

function Test-AlgorithmTool {
    $JsonCommands = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"algorithm_demo","arguments":{"algorithm":"fibonacci","data":"10","show_steps":false}}}'
    )
    
    $JsonInput = $JsonCommands -join "`n"
    $Result = Invoke-MCPCommand -JsonInput $JsonInput -Title "アルゴリズムデモツールテスト結果"
    
    Write-Host
    Write-Host "レスポンス:" -ForegroundColor Green
    Write-Host "-----------" -ForegroundColor Green
    $Result | ForEach-Object { Write-Host $_ }
}

function Show-Help {
    Write-Host "使用方法: .\test-mcp-jp.ps1 [コマンド]" -ForegroundColor Yellow
    Write-Host
    Write-Host "コマンド:" -ForegroundColor Green
    Write-Host "  list-tools      - 利用可能なツール一覧を表示" -ForegroundColor Cyan
    Write-Host "  ツール一覧      - 利用可能なツール一覧を表示" -ForegroundColor Cyan
    Write-Host "  list-resources  - 利用可能なリソース一覧を表示" -ForegroundColor Cyan
    Write-Host "  リソース一覧    - 利用可能なリソース一覧を表示" -ForegroundColor Cyan
    Write-Host "  test-echo       - エコーツールをテスト" -ForegroundColor Cyan
    Write-Host "  エコーテスト    - エコーツールをテスト" -ForegroundColor Cyan
    Write-Host "  test-system     - システム情報ツールをテスト" -ForegroundColor Cyan
    Write-Host "  システム情報    - システム情報ツールをテスト" -ForegroundColor Cyan
    Write-Host "  test-json       - JSONツールをテスト" -ForegroundColor Cyan
    Write-Host "  test-array      - 配列操作ツールをテスト" -ForegroundColor Cyan
    Write-Host "  test-algorithm  - アルゴリズムデモをテスト" -ForegroundColor Cyan
    Write-Host "  help            - このヘルプメッセージを表示" -ForegroundColor Cyan
    Write-Host "  ヘルプ          - このヘルプメッセージを表示" -ForegroundColor Cyan
    Write-Host
    Write-Host "使用例:" -ForegroundColor Green
    Write-Host "  .\test-mcp-jp.ps1 list-tools" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 ツール一覧" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 test-echo" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 エコーテスト" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 test-json" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 test-array" -ForegroundColor White
    Write-Host "  .\test-mcp-jp.ps1 test-algorithm" -ForegroundColor White
    Write-Host
    Write-Host "期待されるツール（全21個）:" -ForegroundColor Green
    Write-Host "  基本ツール (11個):" -ForegroundColor Yellow
    Write-Host "  echo, misezan, delay_response, system_info," -ForegroundColor White
    Write-Host "  file_operations, network_ping, encryption," -ForegroundColor White
    Write-Host "  password_generator, qr_generator, fortune_teller," -ForegroundColor White
    Write-Host "  memory_monitor" -ForegroundColor White
    Write-Host
    Write-Host "  データ構造ツール (10個):" -ForegroundColor Yellow
    Write-Host "  json_manipulator, csv_processor, dictionary_manager," -ForegroundColor White
    Write-Host "  array_operations, sql_simulator, graph_operations," -ForegroundColor White
    Write-Host "  statistics_analyzer, text_analyzer, data_serializer," -ForegroundColor White
    Write-Host "  algorithm_demo" -ForegroundColor White
    Write-Host
    Write-Host "期待されるリソース:" -ForegroundColor Green
    Write-Host "  time://current, datastore://summary" -ForegroundColor White
}

# メインの処理
switch ($Command.ToLower()) {
    "list-tools" { Show-ToolsList }
    "ツール一覧" { Show-ToolsList }
    "list-resources" { Show-ResourcesList }
    "リソース一覧" { Show-ResourcesList }
    "test-echo" { Test-EchoTool }
    "エコーテスト" { Test-EchoTool }
    "test-system" { Test-SystemTool }
    "システム情報" { Test-SystemTool }
    "test-json" { Test-JsonTool }
    "test-array" { Test-ArrayTool }
    "test-algorithm" { Test-AlgorithmTool }
    "help" { Show-Help }
    "ヘルプ" { Show-Help }
    default {
        Write-Host "不明なコマンド: $Command" -ForegroundColor Red
        Write-Host
        Write-Host ".\test-mcp-jp.ps1 help または .\test-mcp-jp.ps1 ヘルプ で使用方法を確認してください。" -ForegroundColor Yellow
    }
}

Write-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "テスト完了。" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($PSCmdlet.MyInvocation.InvocationName -ne '&') {
    Read-Host "Enterキーを押して終了"
}