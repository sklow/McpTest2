@echo off
REM MCP サーバーテストスクリプト（日本語版）

chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo  MCP サーバーテスト（日本語版）
echo ========================================
echo.

REM 実行ファイルの存在確認
set "EXE_PATH=DotNetFrameworkMcpServer\DotNetFrameworkMcpServer\bin\Debug\DotNetFrameworkMcpServer.exe"
if not exist "%EXE_PATH%" (
    echo エラー: %EXE_PATH% が見つかりません！
    echo 最初にプロジェクトをビルドしてください：
    echo   dotnet build DotNetFrameworkMcpServer.sln -c Debug
    echo.
    pause
    exit /b 1
)

echo 実行ファイルを発見: %EXE_PATH%
echo.

REM コマンドライン引数の解析
set "METHOD=%~1"
if "%METHOD%"=="" set "METHOD=help"

if "%METHOD%"=="ツール一覧" goto list_tools
if "%METHOD%"=="list-tools" goto list_tools
if "%METHOD%"=="リソース一覧" goto list_resources
if "%METHOD%"=="list-resources" goto list_resources
if "%METHOD%"=="エコーテスト" goto test_echo
if "%METHOD%"=="test-echo" goto test_echo
if "%METHOD%"=="システム情報" goto test_system
if "%METHOD%"=="test-system" goto test_system
if "%METHOD%"=="ヘルプ" goto show_help
if "%METHOD%"=="help" goto show_help
goto unknown_method

:list_tools
echo ツール一覧を取得中...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo 利用可能なツール:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

REM ツール名を解析して表示
echo.
echo ツール名一覧:
echo -------------
for /f "tokens=*" %%i in ('findstr /C:"\"name\":" "%TEMP%\mcp_output.txt"') do (
    set "line=%%i"
    set "line=!line:*\"name\":=!"
    set "line=!line:\",*=!"
    set "line=!line:\"=!"
    set "line=!line: =!"
    echo   ★ !line!
)

echo.
echo ツール数と詳細:
echo ---------------
findstr /C:"\"name\":" "%TEMP%\mcp_output.txt" | find /C "name"
echo 個のツールが見つかりました。

echo.
echo 完全なJSONレスポンス（最初の500文字）:
echo ------------------------------------
type "%TEMP%\mcp_output.txt" | more

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:list_resources
echo リソース一覧を取得中...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo 利用可能なリソース:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo リソースURI一覧:
echo ----------------
for /f "tokens=*" %%i in ('findstr /C:"\"uri\":" "%TEMP%\mcp_output.txt"') do (
    set "line=%%i"
    set "line=!line:*\"uri\":=!"
    set "line=!line:\",*=!"
    set "line=!line:\"=!"
    set "line=!line: =!"
    echo   ★ !line!
)

echo.
echo 完全なJSONレスポンス:
echo --------------------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:test_echo
echo エコーツールをテスト中...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"echo","arguments":{"message":"こんにちは、MCPテストです！"}}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo エコーツールテスト結果:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo レスポンス:
echo -----------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:test_system
echo システム情報ツールをテスト中...
echo.
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}} > "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","method":"initialized","params":{}} >> "%TEMP%\mcp_input.txt"
echo {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"system_info","arguments":{"info_type":"os"}}} >> "%TEMP%\mcp_input.txt"

echo ========================================
echo システム情報ツールテスト結果:
echo ========================================
type "%TEMP%\mcp_input.txt" | "%EXE_PATH%" > "%TEMP%\mcp_output.txt"

echo.
echo レスポンス:
echo -----------
type "%TEMP%\mcp_output.txt"

del "%TEMP%\mcp_input.txt" "%TEMP%\mcp_output.txt"
goto end

:show_help
echo 使用方法: %0 [コマンド]
echo.
echo コマンド:
echo   list-tools      - 利用可能なツール一覧を表示
echo   ツール一覧      - 利用可能なツール一覧を表示
echo   list-resources  - 利用可能なリソース一覧を表示
echo   リソース一覧    - 利用可能なリソース一覧を表示
echo   test-echo       - エコーツールをテスト
echo   エコーテスト    - エコーツールをテスト
echo   test-system     - システム情報ツールをテスト
echo   システム情報    - システム情報ツールをテスト
echo   help            - このヘルプメッセージを表示
echo   ヘルプ          - このヘルプメッセージを表示
echo.
echo 使用例:
echo   %0 list-tools
echo   %0 ツール一覧
echo   %0 test-echo
echo   %0 エコーテスト
echo.
echo 期待されるツール（全11個）:
echo   echo, misezan, delay_response, system_info,
echo   file_operations, network_ping, encryption,
echo   password_generator, qr_generator, fortune_teller,
echo   memory_monitor
echo.
echo 期待されるリソース:
echo   time://current
goto end

:unknown_method
echo 不明なコマンド: %METHOD%
echo.
echo '%0 help' または '%0 ヘルプ' で使用方法を確認してください。
goto end

:end
echo.
echo ========================================
echo テスト完了。
echo ========================================
pause