# テストケース 04: Swiftツールのコンパイルとリカバリ

**優先度**: Priority 1 - Critical
**カテゴリ**: macOS専用機能・ビルドシステム
**対象OS**: macOS のみ

## 概要

このテストは、macOS専用のSwift IMEツールの自動コンパイル、mtime検出による再コンパイル、およびエラー時のリカバリを検証します。

### テストの重要性

- ✅ **macOSユーザーの初回体験**: コンパイル失敗で機能が使えない
- ✅ **潜在的バグ**: コンパイル失敗時のリトライ機構なし（信頼度85%）
- ✅ **自動メンテナンス**: mtimeベースの再コンパイルがバグ修正の鍵

### 発見された問題

**ファイル**: `/lua/ime-auto/swift-ime-tool.lua` (L90-146)

**問題点**:
1. コンパイル失敗時にリトライ機構がない
2. バイナリ削除後の再コンパイル処理に不具合の可能性
3. ディスク満杯など一時的エラーで永続的に失敗

## 関連ファイル

- `/lua/ime-auto/swift-ime-tool.lua` (L90-146: コンパイル処理, L71-87: mtime検出)
- `/swift/ime-tool.swift` (Swiftソースコード)

## 前提条件

### 環境

```bash
# macOS専用
sw_vers  # macOS確認

# Swiftコンパイラ確認
swiftc --version  # Swift 5.0以降

# Xcode Command Line Tools
xcode-select -p  # /Library/Developer/CommandLineTools
```

### 初期設定

```lua
require("ime-auto").setup({
  os = "macos",  -- 明示的にmacOS指定
  ime_method = "builtin",
  debug = true,
})
```

### クリーンアップ

```bash
# コンパイル済みバイナリ削除（テスト前）
rm -f ~/.local/share/nvim/ime-auto/swift-ime

# ディレクトリごと削除
rm -rf ~/.local/share/nvim/ime-auto/
```

## テストステップ

### Test 4.1: 初回コンパイル成功

**手順**:

1. バイナリとディレクトリが存在しない状態で開始
2. `swift_tool.ensure_compiled()`を呼び出し
3. コンパイル完了を確認
4. バイナリの実行可能性を確認

**期待される結果**:

- ディレクトリ作成: `~/.local/share/nvim/ime-auto/`
- バイナリ生成: `~/.local/share/nvim/ime-auto/swift-ime`
- パーミッション: 実行可能（0755）
- コンパイルエラーなし

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")

-- クリーン状態確認
local data_dir = vim.fn.stdpath('data')
local binary_path = data_dir .. '/ime-auto/swift-ime'
assert.equals(0, vim.fn.filereadable(binary_path))

-- コンパイル実行
local ok, err = swift_tool.ensure_compiled()

-- 成功確認
assert.is_true(ok)
assert.is_nil(err)

-- バイナリ存在確認
assert.equals(1, vim.fn.filereadable(binary_path))

-- 実行可能性確認
assert.equals(1, vim.fn.executable(binary_path))
```

---

### Test 4.2: バイナリ存在時はコンパイルスキップ

**手順**:

1. 既にコンパイル済みバイナリが存在
2. `ensure_compiled()`を呼び出し
3. コンパイルがスキップされることを確認

**期待される結果**:

- コンパイルコマンド(`swiftc`)が実行されない
- 即座に`true`を返す
- バイナリのmtimeが変更されない

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local binary_path = data_dir .. '/ime-auto/swift-ime'

-- 初回コンパイル
swift_tool.ensure_compiled()
local original_mtime = vim.fn.getftime(binary_path)

-- 2回目の呼び出し
local start_time = vim.loop.now()
local ok, err = swift_tool.ensure_compiled()
local elapsed = vim.loop.now() - start_time

assert.is_true(ok)
assert.is_nil(err)

-- 高速に完了（コンパイルなし）
assert.is_true(elapsed < 100) -- 100ms以内

-- mtimeが変更されていない
local new_mtime = vim.fn.getftime(binary_path)
assert.equals(original_mtime, new_mtime)
```

---

### Test 4.3: mtime検出による再コンパイル

**手順**:

1. バイナリをコンパイル
2. Swiftソースコードのmtimeを更新（疑似的に`touch`）
3. `ensure_compiled()`を呼び出し
4. 再コンパイルが実行されることを確認

**期待される結果**:

- ソースmtime > バイナリmtime を検出
- 再コンパイルが自動実行される
- 新しいバイナリが生成される

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local binary_path = data_dir .. '/ime-auto/swift-ime'

-- 初回コンパイル
swift_tool.ensure_compiled()
local original_mtime = vim.fn.getftime(binary_path)

-- ソースmtimeを更新（疑似）
-- 注: 実際にはソースは埋め込まれているため、
-- テストではバイナリを削除して再コンパイルを検証
vim.fn.delete(binary_path)

-- 再コンパイル
local ok, err = swift_tool.ensure_compiled()

assert.is_true(ok)
assert.is_nil(err)

-- 新しいバイナリが生成されている
assert.equals(1, vim.fn.filereadable(binary_path))

local new_mtime = vim.fn.getftime(binary_path)
assert.is_true(new_mtime > original_mtime)
```

---

### Test 4.4: コンパイルエラーのハンドリング

**手順**:

1. `swiftc`コマンドを利用不可にする（モック）
2. `ensure_compiled()`を呼び出し
3. エラーが適切にハンドリングされることを確認

**期待される結果**:

- `ok = false, err = "Failed to compile..."` を返す
- Neovimがクラッシュしない
- エラーメッセージが通知される

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")

-- swiftcコマンドをモック（エラーシミュレーション）
local original_system = vim.fn.system
vim.fn.system = function(cmd)
  if cmd:match("swiftc") then
    vim.v.shell_error = 1
    return "swift: command not found"
  end
  return original_system(cmd)
end

-- バイナリ削除（再コンパイルを強制）
local data_dir = vim.fn.stdpath('data')
local binary_path = data_dir .. '/ime-auto/swift-ime'
vim.fn.delete(binary_path)

-- コンパイル試行
local ok, err = swift_tool.ensure_compiled()

-- エラー確認
assert.is_false(ok)
assert.is_not_nil(err)
assert.is_true(err:match("Failed to compile"))

-- システム復元
vim.fn.system = original_system
```

---

### Test 4.5: ディスク満杯エラーのリカバリ

**手順**:

1. ファイル書き込み失敗をシミュレーション
2. `ensure_compiled()`を呼び出し
3. エラーハンドリングを確認

**期待される結果**:

- ファイルI/Oエラーを検出
- 適切なエラーメッセージ
- 部分的に書き込まれたファイルのクリーンアップ（理想的）

**検証ポイント**:

```lua
-- io.openをモック
local original_io_open = io.open
io.open = function(path, mode)
  if path:match("swift%-ime%.swift") then
    return nil, "No space left on device"
  end
  return original_io_open(path, mode)
end

local swift_tool = require("ime-auto.swift-ime-tool")

-- バイナリ削除
local data_dir = vim.fn.stdpath('data')
vim.fn.delete(data_dir .. '/ime-auto/swift-ime')

-- コンパイル試行
local ok, err = swift_tool.ensure_compiled()

-- エラー確認
assert.is_false(ok)
assert.is_not_nil(err)
assert.is_true(err:match("Failed to open") or err:match("No space"))

-- システム復元
io.open = original_io_open
```

---

### Test 4.6: 並行コンパイルの防止

**手順**:

1. 複数のバッファから同時に`ensure_compiled()`を呼び出し
2. 競合状態が発生しないことを確認

**期待される結果**:

- 最初の呼び出しがコンパイルを実行
- 2番目以降は既存バイナリを使用
- ファイルロックなどで競合を回避（理想的）

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")

-- バイナリ削除
local data_dir = vim.fn.stdpath('data')
vim.fn.delete(data_dir .. '/ime-auto/swift-ime')

-- 並行呼び出しシミュレーション
local results = {}
for i = 1, 3 do
  vim.schedule(function()
    local ok, err = swift_tool.ensure_compiled()
    table.insert(results, { ok = ok, err = err })
  end)
end

-- すべての完了を待機
vim.wait(5000, function() return #results == 3 end)

-- すべて成功しているはず
for i, result in ipairs(results) do
  assert.is_true(result.ok, "Call " .. i .. " should succeed")
end
```

---

### Test 4.7: Swiftツールの実際の動作確認

**手順**:

1. コンパイル成功後、実際にSwiftツールを呼び出し
2. IME切り替えが動作することを確認

**期待される結果**:

- `toggle-from-insert`コマンドが成功
- `toggle-from-normal`コマンドが成功
- `get-current`コマンドでIME IDを取得できる

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")

-- コンパイル確認
local ok = swift_tool.ensure_compiled()
assert.is_true(ok)

-- 現在のIME取得
local current_ime = swift_tool.get_current()
assert.is_not_nil(current_ime)
assert.is_true(#current_ime > 0)

-- トグル実行
local toggle_ok = swift_tool.toggle_from_insert()
assert.is_true(toggle_ok)

-- IMEが変更されたか確認
local after_toggle = swift_tool.get_current()
assert.is_not_nil(after_toggle)

-- 元に戻す
toggle_ok = swift_tool.toggle_from_normal()
assert.is_true(toggle_ok)

local restored = swift_tool.get_current()
assert.equals(current_ime, restored)
```

## 実装例

```lua
-- tests/priority-1/swift_tool_compilation_spec.lua
local swift_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: Swift tool compilation (macOS only)", function()
  local data_dir = vim.fn.stdpath('data')
  local ime_auto_dir = data_dir .. '/ime-auto'
  local binary_path = ime_auto_dir .. '/swift-ime'

  before_each(function()
    -- macOSでのみ実行
    if vim.fn.has("mac") == 0 then
      pending("This test is macOS only")
      return
    end

    -- swiftc確認
    if vim.fn.executable("swiftc") == 0 then
      pending("swiftc not found. Install Xcode Command Line Tools.")
      return
    end
  end)

  after_each(function()
    -- テスト後のクリーンアップ（オプション）
    -- vim.fn.delete(binary_path)
  end)

  describe("4.1: 初回コンパイル成功", function()
    it("should compile Swift tool on first run", function()
      -- バイナリ削除（クリーン状態）
      vim.fn.delete(binary_path)

      local ok, err = swift_tool.ensure_compiled()

      assert.is_true(ok)
      assert.is_nil(err)
      assert.equals(1, vim.fn.filereadable(binary_path))
      assert.equals(1, vim.fn.executable(binary_path))
    end)
  end)

  describe("4.2: バイナリ存在時はコンパイルスキップ", function()
    it("should skip compilation if binary exists", function()
      -- 事前コンパイル
      swift_tool.ensure_compiled()
      local original_mtime = vim.fn.getftime(binary_path)

      -- 2回目
      local start_time = vim.loop.now()
      local ok, err = swift_tool.ensure_compiled()
      local elapsed = vim.loop.now() - start_time

      assert.is_true(ok)
      assert.is_true(elapsed < 100)

      local new_mtime = vim.fn.getftime(binary_path)
      assert.equals(original_mtime, new_mtime)
    end)
  end)

  describe("4.3: バイナリ削除後の再コンパイル", function()
    it("should recompile if binary is deleted", function()
      -- 初回コンパイル
      swift_tool.ensure_compiled()

      -- バイナリ削除
      vim.fn.delete(binary_path)
      assert.equals(0, vim.fn.filereadable(binary_path))

      -- 再コンパイル
      local ok, err = swift_tool.ensure_compiled()

      assert.is_true(ok)
      assert.is_nil(err)
      assert.equals(1, vim.fn.filereadable(binary_path))
    end)
  end)

  describe("4.4: コンパイルエラーのハンドリング", function()
    it("should handle swiftc command failure", function()
      -- swiftcをモック
      local original_system = vim.fn.system
      vim.fn.system = function(cmd)
        if cmd:match("swiftc") then
          vim.v.shell_error = 1
          return "compilation failed"
        end
        return original_system(cmd)
      end

      vim.fn.delete(binary_path)

      local ok, err = swift_tool.ensure_compiled()

      assert.is_false(ok)
      assert.is_not_nil(err)
      assert.is_true(err:match("Failed to compile"))

      vim.fn.system = original_system
    end)
  end)

  describe("4.7: Swiftツールの実際の動作確認", function()
    it("should execute Swift tool commands", function()
      local ok = swift_tool.ensure_compiled()
      assert.is_true(ok)

      local current_ime = swift_tool.get_current()
      assert.is_not_nil(current_ime)
      assert.is_true(#current_ime > 0)

      -- トグル実行
      local toggle_ok = swift_tool.toggle_from_insert()
      assert.is_true(toggle_ok)

      -- 元に戻す
      toggle_ok = swift_tool.toggle_from_normal()
      assert.is_true(toggle_ok)
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **Swiftコンパイラのバージョン**
   ```bash
   swiftc --version
   # Swift version 5.0 以降であるべき
   ```

2. **ディレクトリパーミッション**
   ```bash
   ls -ld ~/.local/share/nvim/
   # rwxr-xr-x であるべき
   ```

3. **ディスクスペース**
   ```bash
   df -h ~/.local/share/nvim/
   ```

4. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   xcode-select -p
   ```

### 既知の問題

- **M1/M2 Mac**: Rosetta経由のSwiftコンパイルは遅い可能性
- **古いmacOS**: macOS 10.14以前はSwift 5非対応
- **Sandbox環境**: 一部のセキュリティ設定でコンパイルが失敗

## 成功基準

以下のすべての条件を満たすこと：

- ✅ 初回コンパイルが成功する
- ✅ バイナリ存在時はコンパイルをスキップする
- ✅ バイナリ削除後に自動再コンパイルされる
- ✅ コンパイルエラーが適切にハンドリングされる
- ✅ 並行コンパイルで競合状態が発生しない
- ✅ コンパイル後のSwiftツールが正常動作する

## 関連テストケース

- [01: 基本的なIME切り替え](./01-basic-ime-switching.md)
- [05: IME状態の保存と復元](./05-ime-state-persistence.md)
- [08: macOS slot初期化](../priority-2-important/08-macos-slot-initialization.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
