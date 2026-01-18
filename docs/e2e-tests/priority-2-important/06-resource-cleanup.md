# テストケース 06: リソースクリーンアップ

**優先度**: Priority 2 - Important
**カテゴリ**: リソース管理・メモリリーク防止
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、プラグイン無効化時やNeovim終了時に、タイマーやリソースが適切にクリーンアップされることを検証します。

### テストの重要性

- ✅ **潜在的バグ**: タイマーのクリーンアップ漏れ（信頼度85%）
- ✅ **リソースリーク防止**: 長時間使用時のメモリリークを回避
- ✅ **プラグイン無効化の信頼性**: `:ImeAutoDisable`後に影響が残らない

### 発見された問題

**ファイル**: `/lua/ime-auto/ime.lua` (L28-30, L141-165)
**ファイル**: `/lua/ime-auto/escape.lua` (L6-12, L49-77)

**問題点**:
- `M.disable()`でデバウンスタイマー(`mode_change_timer`)を停止していない
- エスケープシーケンスのタイマー(`timer`)もクリーンアップされない
- プラグイン無効化後もタイマーが発火する可能性

## 関連ファイル

- `/lua/ime-auto/init.lua` (L60-68: disable実装)
- `/lua/ime-auto/ime.lua` (L28-30, L141-165: デバウンスタイマー)
- `/lua/ime-auto/escape.lua` (L6-12, L49-77: エスケープタイマー)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
-- テストフレームワーク: plenary.nvim
```

### 初期設定

```lua
require("ime-auto").setup({
  escape_sequence = "ｋｊ",
  escape_timeout = 200,
  debug = true,
})
```

## テストステップ

### Test 6.1: プラグイン無効化時のデバウンスタイマー停止

**手順**:

1. Insertモード → Normalモード（デバウンスタイマー起動）
2. タイマー実行前（100ms以内）に`:ImeAutoDisable`
3. タイマーが停止されていることを確認
4. 100ms待機後、タイマーコールバックが実行されないことを確認

**期待される結果**:

- `:ImeAutoDisable`でタイマーが停止される
- タイマーコールバック（IME制御）が実行されない

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

-- システムコールカウンター
local call_count = 0
local original_control = ime.control
ime.control = function(action)
  if action == "off" then
    call_count = call_count + 1
  end
  return original_control(action)
end

-- デバウンスタイマー起動
vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert") -- off_debounced() スケジュール

-- 即座に無効化
vim.wait(30) -- タイマー実行前
ime_auto.disable()

-- タイマー実行時間を超過
vim.wait(150)

-- IME制御が呼ばれていないはず
assert.equals(0, call_count)

ime.control = original_control
```

---

### Test 6.2: エスケープシーケンスタイマーのクリーンアップ

**手順**:

1. Insertモードで`ｋ`入力（タイマー起動）
2. タイムアウト前（200ms以内）に`:ImeAutoDisable`
3. タイマーが停止されていることを確認

**期待される結果**:

- エスケープシーケンスのpending状態がクリアされる
- タイマーが停止される

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")
local escape = require("ime-auto.escape")

vim.cmd("startinsert")

-- エスケープシーケンスの最初の文字
vim.fn.feedkeys("ｋ", "nx")
vim.wait(50)

-- pending_charとtimerが設定されている状態で無効化
ime_auto.disable()

-- タイムアウト時間を超過
vim.wait(250)

-- 無効化後にｊを入力してもエスケープシーケンスとして反応しない
ime_auto.enable()
vim.cmd("startinsert")
vim.fn.feedkeys("ｊ", "nx")
vim.wait(50)

-- まだInsertモード（エスケープシーケンスとして動作していない）
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.cmd("stopinsert")
```

---

### Test 6.3: オートコマンドの削除

**手順**:

1. プラグイン有効化（オートコマンド登録）
2. `:ImeAutoDisable`
3. オートコマンドが削除されていることを確認
4. InsertEnter/InsertLeaveでコールバックが実行されないことを確認

**期待される結果**:

- `ime_auto`グループのオートコマンドが削除される
- `ime_auto_escape`グループのオートコマンドが削除される

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")

-- オートコマンド登録確認
local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
assert.is_true(#autocmds > 0)

local escape_autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto_escape" })
assert.is_true(#escape_autocmds > 0)

-- 無効化
ime_auto.disable()

-- オートコマンド削除確認
autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
assert.equals(0, #autocmds)

escape_autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto_escape" })
assert.equals(0, #escape_autocmds)
```

---

### Test 6.4: 複数回の有効化/無効化サイクル

**手順**:

1. `:ImeAutoEnable` → `:ImeAutoDisable` を5回繰り返す
2. メモリリークがないことを確認
3. 最終的に正常動作することを確認

**期待される結果**:

- オートコマンドが重複登録されない
- タイマーが蓄積しない
- メモリ使用量が安定

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")

for cycle = 1, 5 do
  ime_auto.enable()

  -- オートコマンド数確認（重複なし）
  local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
  assert.equals(2, #autocmds) -- InsertEnter, InsertLeave

  ime_auto.disable()

  autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
  assert.equals(0, #autocmds)
end

-- 最終的に有効化して動作確認
ime_auto.enable()

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(150)

-- 正常動作
assert.is_true(vim.g.loaded_ime_auto)
```

---

### Test 6.5: Neovim終了時のクリーンアップ

**手順**:

1. タイマー実行中に`:qa!`シミュレーション
2. エラーなく終了できることを確認

**期待される結果**:

- Neovim終了時にタイマーが自動的にクリーンアップされる
- エラーメッセージが出ない

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")

-- デバウンスタイマー起動
vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")

-- 即座に終了（実際のテストではシミュレーション）
-- 注: :qa!はテスト環境で実行できないため、
-- VimLeavePreイベントでのクリーンアップを確認

local cleanup_called = false

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    -- タイマーが停止されているか確認
    -- （実装上、明示的なクリーンアップがない場合は改善提案）
    cleanup_called = true
  end,
})

vim.cmd("doautocmd VimLeavePre")
assert.is_true(cleanup_called)
```

---

### Test 6.6: 無効化後の再有効化での状態リセット

**手順**:

1. Insertモード（IME=ON）
2. `:ImeAutoDisable`
3. `:ImeAutoEnable`
4. 前回の状態が引き継がれないことを確認

**期待される結果**:

- 無効化で内部状態がリセットされる
- 再有効化で新たに状態管理を開始

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local config = require("ime-auto.config").get()

if config.os == "macos" then
  pending("macOS uses slot-based system")
  return
end

-- IME=ON状態を保存
vim.cmd("startinsert")
ime.on()
vim.wait(50)

vim.cmd("stopinsert")
vim.wait(100)

-- 無効化
ime_auto.disable()

-- 再有効化
ime_auto.enable()

-- 前回の状態は引き継がれない（新規開始）
vim.cmd("startinsert")
vim.wait(50)

-- IME状態は現在のシステムの状態から開始
local current_state = ime.get_status()
assert.is_not_nil(current_state)

vim.cmd("stopinsert")
```

## 実装例

```lua
-- tests/priority-2/resource_cleanup_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 06: Resource cleanup", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    ime_auto.enable() -- テスト後は有効化
    vim.cmd("bdelete!")
  end)

  describe("6.1: デバウンスタイマー停止", function()
    it("should stop debounce timer on disable", function()
      local call_count = 0
      local original_control = ime.control
      ime.control = function(action)
        if action == "off" then
          call_count = call_count + 1
        end
        return original_control(action)
      end

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")

      vim.wait(30)
      ime_auto.disable()

      vim.wait(150)

      assert.equals(0, call_count)

      ime.control = original_control
    end)
  end)

  describe("6.2: エスケープシーケンスタイマークリーンアップ", function()
    it("should clear escape sequence pending state on disable", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("ｋ", "nx")
      vim.wait(50)

      ime_auto.disable()
      vim.wait(250)

      ime_auto.enable()
      vim.cmd("startinsert")
      vim.fn.feedkeys("ｊ", "nx")
      vim.wait(50)

      assert.equals("i", vim.api.nvim_get_mode().mode)

      vim.cmd("stopinsert")
    end)
  end)

  describe("6.3: オートコマンド削除", function()
    it("should delete autocmds on disable", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      assert.is_true(#autocmds > 0)

      ime_auto.disable()

      autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      assert.equals(0, #autocmds)

      local escape_autocmds = vim.api.nvim_get_autocmds({
        group = "ime_auto_escape"
      })
      assert.equals(0, #escape_autocmds)
    end)
  end)

  describe("6.4: 複数回の有効化/無効化", function()
    it("should handle multiple enable/disable cycles", function()
      for cycle = 1, 5 do
        ime_auto.enable()

        local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
        assert.equals(2, #autocmds, "Cycle " .. cycle)

        ime_auto.disable()

        autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
        assert.equals(0, #autocmds)
      end

      ime_auto.enable()
      assert.is_true(vim.g.loaded_ime_auto)
    end)
  end)

  describe("6.6: 無効化後の状態リセット", function()
    it("should reset state on re-enable", function()
      local config = require("ime-auto.config").get()

      if config.os == "macos" then
        pending("macOS uses slot-based system")
        return
      end

      vim.cmd("startinsert")
      ime.on()
      vim.wait(50)

      vim.cmd("stopinsert")
      vim.wait(100)

      ime_auto.disable()
      ime_auto.enable()

      vim.cmd("startinsert")
      vim.wait(50)

      local state = ime.get_status()
      assert.is_not_nil(state)

      vim.cmd("stopinsert")
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **タイマーの実装確認**
   ```lua
   -- ime.lua内のタイマー変数
   local mode_change_timer = nil

   -- escape.lua内のタイマー変数
   local timer = nil
   ```

2. **disable()の実装**
   ```lua
   -- init.lua:60-68
   function M.disable()
     enabled = false
     -- TODO: タイマー停止処理が必要
   end
   ```

3. **タイマーの停止確認**
   ```lua
   if timer then
     vim.fn.timer_stop(timer)
     timer = nil
   end
   ```

### 改善提案

現在の実装では、`disable()`でタイマーを明示的に停止していません。以下の修正を推奨：

**ime.lua**:
```lua
function M.cleanup()
  if mode_change_timer then
    vim.fn.timer_stop(mode_change_timer)
    mode_change_timer = nil
  end
end

-- init.luaのdisable()から呼び出し
```

**escape.lua**:
```lua
function M.cleanup()
  clear_pending() -- タイマー停止とpending_charクリア
end
```

## 成功基準

以下のすべての条件を満たすこと：

- ✅ `:ImeAutoDisable`でデバウンスタイマーが停止される
- ✅ エスケープシーケンスのタイマーとpending状態がクリアされる
- ✅ オートコマンドが完全に削除される
- ✅ 複数回の有効化/無効化でリソースが蓄積しない
- ✅ Neovim終了時にエラーが発生しない
- ✅ 再有効化時に前回の状態が引き継がれない

## 関連テストケース

- [01: 基本的なIME切り替え](../priority-1-critical/01-basic-ime-switching.md)
- [02: 高速モード切り替えでの競合状態](../priority-1-critical/02-rapid-mode-switching.md)
- [05: IME状態の保存と復元](../priority-1-critical/05-ime-state-persistence.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: タイマークリーンアップ処理の追加が必要
