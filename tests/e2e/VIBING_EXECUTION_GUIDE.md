# vibing.nvim エージェント向けE2Eテスト実行ガイド

このドキュメントは、vibing.nvimのエージェントがime-auto.nvimのE2Eテストを実行するための手順書です。

## 実行方法

### 方法1: Luaスクリプトで実行（推奨）

```lua
-- すべての自動テストを実行
local e2e = require("tests.e2e.vibing_test_runner")
e2e.run_all_tests()
```

### 方法2: 個別テストを実行

```lua
local e2e = require("tests.e2e.vibing_test_runner")

-- プラグイン初期化テスト
e2e.run_test("initialization")

-- Swiftツールテスト
e2e.run_test("swift_tool")

-- スロット永続化テスト
e2e.run_test("slot_persistence")
```

### 方法3: Neovimコマンドで実行

```vim
:lua require("tests.e2e.vibing_test_runner").run_all_tests()
```

---

## エージェント向けタスク定義

vibing.nvimエージェントがこのドキュメントを読んで実行する際の指示です。

### Task 1: 環境確認

**目的**: テスト実行に必要な環境が整っているか確認

**実行内容**:
```lua
-- Neovimバージョン確認
print("Neovim version:", vim.version().major .. "." .. vim.version().minor)

-- macOS確認
print("OS:", vim.loop.os_uname().sysname)

-- Swiftコンパイラ確認
local swiftc = vim.fn.executable("swiftc")
print("swiftc available:", swiftc == 1)

-- 日本語IME確認
local ime_list = vim.fn.system("swift " .. vim.fn.expand("~/.local/share/nvim/ime-auto/swift-ime") .. " list")
print("Available IMEs:", ime_list)
```

**期待結果**:
- Neovim 0.8以上
- macOS
- swiftcが利用可能
- 日本語IMEが利用可能

---

### Task 2: 自動テスト実行

**目的**: 自動実行可能なテストをすべて実行

**実行内容**:
```lua
-- テストランナー読み込み
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"
local e2e = require("tests.e2e.vibing_test_runner")

-- 自動テスト実行
local results = e2e.run_all_tests()

-- 結果確認
for _, result in ipairs(results) do
  print(string.format("[%s] %s: %s",
    result.passed and "PASS" or "FAIL",
    result.name,
    result.message
  ))
end
```

**期待結果**:
- すべてのテストがPASS

---

### Task 3: 半自動テスト実行（IME切り替え確認）

**目的**: 実際のIME切り替え動作を確認

**実行内容** (vibing.nvimエージェントが以下を順番に実行):

#### Step 3.1: 新しいバッファを開く
```lua
vim.cmd("enew!")
```

#### Step 3.2: Insert modeに入る
```lua
vim.cmd("startinsert")
vim.wait(200)
```

#### Step 3.3: IME状態確認（初期状態）
```lua
local ime = require("ime-auto.ime")
local status_initial = ime.get_status()
print("Initial IME status in Insert mode:", status_initial)
```

#### Step 3.4: 日本語IMEに切り替える（手動操作が必要）
**エージェントへの指示**:
> macOSのIME切り替えショートカット（通常 Ctrl+Space または ⌘+Space）を送信して、
> 日本語IMEに切り替えてください。
>
> 具体的な実装例:
> ```lua
> -- nvim_input経由でキー送信（実際のキー送信はできないため、注意喚起のみ）
> -- ⚠️ この部分は人間が手動で行う必要があります
> print("⚠️  手動操作が必要: 日本語IMEに切り替えてください")
> print("    macOSのIME切り替えショートカット: Ctrl+Space または ⌘+Space")
> vim.wait(3000)  -- 3秒待機
> ```

#### Step 3.5: 日本語入力
```lua
-- 日本語で何か入力（例: てすと）
vim.api.nvim_feedkeys("てすと", "n", false)
vim.wait(500)
```

#### Step 3.6: Normal modeに戻る
```lua
vim.cmd("stopinsert")
vim.wait(200)
```

#### Step 3.7: IME状態確認（Normal mode）
```lua
local status_normal = ime.get_status()
print("IME status in Normal mode:", status_normal)
-- 期待値: false (英語IME)

local current_ime = require("ime-auto.swift-ime-tool").get_current()
print("Current IME in Normal mode:", current_ime)
-- 期待値: "com.apple.keylayout.ABC" など
```

#### Step 3.8: 再度Insert modeに入る
```lua
vim.cmd("startinsert")
vim.wait(200)
```

#### Step 3.9: IME状態確認（復元確認）
```lua
local status_restored = ime.get_status()
print("IME status restored in Insert mode:", status_restored)
-- 期待値: true (日本語IME)

local restored_ime = require("ime-auto.swift-ime-tool").get_current()
print("Restored IME:", restored_ime)
-- 期待値: "com.apple.inputmethod.Kotoeri.Japanese" など
```

**期待結果**:
- Normal modeでIMEが英語になる
- Insert modeで日本語IMEに復元される

---

### Task 4: スロットファイル確認

**目的**: IME状態がファイルに保存されているか確認

**実行内容**:
```lua
-- スロットファイルパス
local slot_a = vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-a.txt")
local slot_b = vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-b.txt")

-- 存在確認
print("Slot A exists:", vim.fn.filereadable(slot_a) == 1)
print("Slot B exists:", vim.fn.filereadable(slot_b) == 1)

-- 内容確認
if vim.fn.filereadable(slot_a) == 1 then
  local content_a = vim.fn.readfile(slot_a)
  print("Slot A content:", content_a[1])
end

if vim.fn.filereadable(slot_b) == 1 then
  local content_b = vim.fn.readfile(slot_b)
  print("Slot B content:", content_b[1])
end

-- パーミッション確認
print("Slot A permissions:", vim.fn.getfperm(slot_a))
-- 期待値: rw------- (0600)
```

**期待結果**:
- スロットファイルが存在する
- 適切なパーミッション（0600）
- IME IDが正しく保存されている

---

### Task 5: エスケープシーケンステスト

**目的**: 全角文字「ｋｊ」でのエスケープが動作するか確認

**実行内容**:

#### Step 5.1: 新しいバッファ準備
```lua
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
```

#### Step 5.2: Insert modeに入る
```lua
vim.cmd("startinsert")
vim.wait(100)
```

#### Step 5.3: 全角「ｋｊ」を入力
```lua
-- ⚠️ 注意: これは日本語IMEがONの状態で入力する必要がある
vim.api.nvim_feedkeys("ｋｊ", "n", false)
vim.wait(300)  -- escape timeout (200ms) より長く待つ
```

#### Step 5.4: モード確認
```lua
local mode = vim.api.nvim_get_mode().mode
print("Current mode after ｋｊ:", mode)
-- 期待値: "n" (Normal mode)
```

#### Step 5.5: バッファ内容確認
```lua
local line = vim.api.nvim_get_current_line()
print("Buffer content:", vim.inspect(line))
-- 期待値: "" (空文字列、ｋｊが残っていない)
```

**期待結果**:
- Normal modeに戻る
- バッファに「ｋｊ」が残らない

---

## テスト結果の確認

テスト実行後、結果は以下に保存されます：

```
~/.local/share/nvim/ime-auto/e2e-test-report.json
```

### 結果ファイルの確認

```lua
local report_path = vim.fn.expand("~/.local/share/nvim/ime-auto/e2e-test-report.json")
local report = vim.fn.readfile(report_path)
local data = vim.json.decode(table.concat(report, "\n"))

print("Test Summary:")
print("  Total:  ", data.summary.total)
print("  Passed: ", data.summary.passed)
print("  Failed: ", data.summary.failed)

if data.summary.failed > 0 then
  print("\nFailed tests:")
  for _, result in ipairs(data.results) do
    if not result.passed then
      print("  -", result.name, ":", result.message)
    end
  end
end
```

---

## トラブルシューティング

### エラー: `module 'tests.e2e.vibing_test_runner' not found`

**原因**: Luaのモジュールパスが設定されていない

**解決方法**:
```lua
-- プロジェクトルートをパスに追加
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"
local e2e = require("tests.e2e.vibing_test_runner")
```

### エラー: Swiftツールがコンパイルされない

**確認**:
```bash
which swiftc
# なければ: xcode-select --install
```

### IMEが切り替わらない

**デバッグ**:
```lua
-- デバッグモード有効化
require("ime-auto").setup({ debug = true })

-- ログ確認
vim.cmd("messages")
```

---

## vibing.nvimエージェントへの推奨実行順序

1. **Task 1: 環境確認** → 前提条件チェック
2. **Task 2: 自動テスト実行** → 基本機能確認
3. **Task 4: スロットファイル確認** → 永続化確認
4. **Task 3: 半自動テスト実行** → 実際のIME切り替え確認（手動操作が必要）
5. **Task 5: エスケープシーケンステスト** → 高度な機能確認（手動操作が必要）

**注意**: Task 3とTask 5は、macOSのIME切り替えショートカットを送信する必要があるため、
完全自動化は困難です。vibing.nvimエージェントには「手動操作が必要」と通知してください。

---

## サンプル実行スクリプト

vibing.nvimエージェントが直接実行できる完全なスクリプト：

```lua
-- E2E Test Execution for vibing.nvim agent
print("=== IME-AUTO.NVIM E2E Test Execution ===\n")

-- プロジェクトルートからの実行を想定
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"

-- Task 1: 環境確認
print("Task 1: Environment Check")
print("Neovim version:", vim.version().major .. "." .. vim.version().minor)
print("OS:", vim.loop.os_uname().sysname)
print("swiftc available:", vim.fn.executable("swiftc") == 1)
print("")

-- Task 2: 自動テスト実行
print("Task 2: Running automated tests")
local e2e = require("tests.e2e.vibing_test_runner")
local results = e2e.run_all_tests()
print("")

-- Task 4: スロットファイル確認
print("Task 4: Checking slot files")
local slot_a = vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-a.txt")
if vim.fn.filereadable(slot_a) == 1 then
  print("✅ Slot A exists:", vim.fn.readfile(slot_a)[1])
else
  print("❌ Slot A not found")
end
print("")

-- Task 3: 半自動テスト（手動操作必要）
print("Task 3: Manual IME switching test")
print("⚠️  This requires manual IME switching via macOS shortcuts")
print("    Please follow MANUAL_TEST_GUIDE.md for detailed steps")
print("")

print("=== Test Execution Complete ===")
print("See detailed report: ~/.local/share/nvim/ime-auto/e2e-test-report.json")
```

このスクリプトを実行するには：

```vim
:source tests/e2e/vibing_execution_script.lua
```

または：

```bash
nvim -c "source tests/e2e/vibing_execution_script.lua"
```
