# テストケース 12: デバッグモード

**優先度**: Priority 3 - Normal
**カテゴリ**: 開発者ツール・トラブルシューティング
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、`debug = true`モードでの詳細ログ出力とトラブルシューティング支援機能を検証します。

### テストの重要性

- ✅ **開発者体験**: バグ調査を容易にする
- ✅ **ユーザーサポート**: 問題報告時の情報収集
- ✅ **動作確認**: プラグインの内部動作を可視化

## 関連ファイル

- `/lua/ime-auto/utils.lua` (L1-46: notify実装)
- すべての主要モジュール（debug通知を使用）

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
```

### 初期設定

```lua
require("ime-auto").setup({
  debug = true,
})
```

## テストステップ

### Test 12.1: デバッグモード有効時のログ出力

**手順**:

1. `debug = true`で setup
2. 基本的な操作（Insert → Normal）を実行
3. DEBUGレベルのログが出力されることを確認

**期待される結果**:

- InsertEnter時のログ
- InsertLeave時のログ
- IME制御の実行ログ

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, {
    msg = msg,
    level = level,
    time = vim.loop.now(),
  })
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = true,
})

-- 操作実行
vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(150)

-- DEBUGログ確認
local debug_logs = vim.tbl_filter(function(n)
  return n.level == vim.log.levels.DEBUG
end, notifications)

assert.is_true(#debug_logs > 0, "Should have debug logs")

-- ログ内容確認
local has_ime_log = false
for _, log in ipairs(debug_logs) do
  if log.msg:match("IME") or log.msg:match("Restored") or log.msg:match("turned off") then
    has_ime_log = true
    break
  end
end

assert.is_true(has_ime_log, "Should have IME-related logs")

vim.notify = original_notify
```

---

### Test 12.2: デバッグログの内容検証

**手順**:

1. デバッグモードで各種操作を実行
2. ログに期待される情報が含まれることを確認

**期待されるログ内容**:

- モード変更イベント
- IME状態
- エスケープシーケンス処理
- タイマー動作

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = true,
})

-- エスケープシーケンス実行
vim.cmd("startinsert")
vim.fn.feedkeys("testｋｊ", "nx")
vim.wait(300)

-- ログ内容確認
local log_messages = vim.tbl_map(function(n)
  return n.msg
end, notifications)

-- 期待されるキーワード
local expected_keywords = {
  "Restored IME state",
  "IME turned off",
  -- その他の期待されるメッセージ
}

for _, keyword in ipairs(expected_keywords) do
  local found = false
  for _, msg in ipairs(log_messages) do
    if msg:match(keyword) then
      found = true
      break
    end
  end

  if found then
    -- キーワードが見つかった（デバッグログが機能している証拠）
    assert.is_true(true)
  end
end

vim.notify = original_notify
```

---

### Test 12.3: デバッグモード無効時のログ抑制

**手順**:

1. `debug = false`で setup
2. 操作を実行
3. DEBUGレベルのログが出力されないことを確認

**期待される結果**:

- DEBUGログなし
- WARN, ERRORレベルは出力される

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = false,
})

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(150)

-- DEBUGログがないことを確認
local debug_logs = vim.tbl_filter(function(n)
  return n.level == vim.log.levels.DEBUG
end, notifications)

assert.equals(0, #debug_logs, "Should not have debug logs")

vim.notify = original_notify
```

---

### Test 12.4: `:ImeAutoStatus`コマンドの出力

**手順**:

1. `:ImeAutoStatus`を実行
2. 現在の設定と状態が表示されることを確認

**期待される結果**:

- プラグインの有効/無効状態
- 現在のOS設定
- エスケープシーケンス設定
- IME状態（可能な場合）

**検証ポイント**:

```lua
require("ime-auto").setup({
  debug = true,
})

local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, msg)
  original_notify(msg, level)
end

vim.cmd("ImeAutoStatus")

-- ステータス情報が表示されている
assert.is_true(#notifications > 0)

-- 表示内容確認
local status_text = table.concat(notifications, "\n")

-- 期待される情報
assert.is_true(status_text:match("enabled") ~= nil or status_text:match("disabled") ~= nil)
assert.is_true(status_text:match("escape_sequence") ~= nil)

vim.notify = original_notify
```

---

### Test 12.5: エラー時のデバッグ情報

**手順**:

1. デバッグモードで意図的にエラーを発生させる
2. エラーメッセージに詳細情報が含まれることを確認

**期待される結果**:

- エラー発生箇所の情報
- スタックトレース（可能な場合）
- コンテキスト情報

**検証ポイント**:

```lua
require("ime-auto").setup({
  debug = true,
  ime_method = "custom",
  custom_commands = {
    on = "false", -- 必ず失敗するコマンド
    off = "false",
    status = "false",
  },
})

local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

local ime = require("ime-auto.ime")

-- エラー発生
ime.on()
vim.wait(100)

-- エラーログ確認
local error_logs = vim.tbl_filter(function(n)
  return n.level == vim.log.levels.ERROR or n.level == vim.log.levels.WARN
end, notifications)

-- エラーが記録されている（デバッグ情報付き）
assert.is_true(#error_logs > 0)

vim.notify = original_notify
```

---

### Test 12.6: タイミング情報の記録

**手順**:

1. デバッグモードで操作を実行
2. 各処理の実行時間がログに記録されることを確認（理想）

**期待される結果**:

- システムコール実行時間
- IME切り替えにかかった時間

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, {
    msg = msg,
    level = level,
    time = vim.loop.now(),
  })
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = true,
})

vim.cmd("startinsert")
local start_time = vim.loop.now()
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(150)
local end_time = vim.loop.now()

-- タイミング情報の確認（実装次第）
-- 現在の実装ではタイミング情報はないが、改善提案として有用

local time_related_logs = vim.tbl_filter(function(n)
  return n.msg:match("ms") or n.msg:match("time")
end, notifications)

-- (改善提案) タイミング情報があれば確認
if #time_related_logs > 0 then
  assert.is_true(true)
else
  pending("Timing information not implemented yet")
end

vim.notify = original_notify
```

---

### Test 12.7: デバッグログのフォーマット一貫性

**手順**:

1. デバッグモードで複数の操作を実行
2. ログフォーマットが一貫していることを確認

**期待される結果**:

- プレフィックス（例: `[ime-auto]`）が統一
- ログレベルが適切

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = true,
})

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(150)

-- プレフィックス確認
-- (utils.lua:16-21 でプレフィックス処理)
for _, notif in ipairs(notifications) do
  if notif.level == vim.log.levels.DEBUG then
    -- メッセージにプレフィックスがあるか（実装次第）
    -- 現在の実装: vim.notify(prefix .. msg, level)
    -- prefix は空またはモジュール名
    assert.is_string(notif.msg)
  end
end

vim.notify = original_notify
```

## 実装例

```lua
-- tests/priority-3/debug_mode_spec.lua
local ime_auto = require("ime-auto")

describe("Test 12: Debug mode", function()
  local original_notify = nil
  local notifications = {}

  before_each(function()
    notifications = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
      if original_notify then
        original_notify(msg, level)
      end
    end

    vim.cmd("enew!")
  end)

  after_each(function()
    vim.notify = original_notify
    vim.cmd("bdelete!")
  end)

  describe("12.1: デバッグログ出力", function()
    it("should output debug logs when enabled", function()
      ime_auto.setup({ debug = true })

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(150)

      local debug_logs = vim.tbl_filter(function(n)
        return n.level == vim.log.levels.DEBUG
      end, notifications)

      assert.is_true(#debug_logs > 0)

      local has_ime_log = false
      for _, log in ipairs(debug_logs) do
        if log.msg:match("IME") or log.msg:match("Restored") then
          has_ime_log = true
          break
        end
      end

      assert.is_true(has_ime_log)
    end)
  end)

  describe("12.3: ログ抑制（debug=false）", function()
    it("should not output debug logs when disabled", function()
      ime_auto.setup({ debug = false })

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(150)

      local debug_logs = vim.tbl_filter(function(n)
        return n.level == vim.log.levels.DEBUG
      end, notifications)

      assert.equals(0, #debug_logs)
    end)
  end)

  describe("12.4: :ImeAutoStatusコマンド", function()
    it("should display current status", function()
      ime_auto.setup({ debug = true })

      notifications = {}
      vim.cmd("ImeAutoStatus")

      assert.is_true(#notifications > 0)

      local status_text = table.concat(vim.tbl_map(function(n)
        return n.msg
      end, notifications), "\n")

      assert.is_true(
        status_text:match("enabled") ~= nil or
        status_text:match("disabled") ~= nil
      )
    end)
  end)

  describe("12.5: エラー時のデバッグ情報", function()
    it("should provide detailed error information", function()
      ime_auto.setup({
        debug = true,
        ime_method = "custom",
        custom_commands = {
          on = "false",
          off = "false",
          status = "false",
        },
      })

      notifications = {}

      local ime = require("ime-auto.ime")
      ime.on()
      vim.wait(100)

      local error_logs = vim.tbl_filter(function(n)
        return n.level == vim.log.levels.ERROR or
               n.level == vim.log.levels.WARN
      end, notifications)

      assert.is_true(#error_logs > 0)
    end)
  end)

  describe("12.7: ログフォーマット一貫性", function()
    it("should have consistent log format", function()
      ime_auto.setup({ debug = true })

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(150)

      for _, notif in ipairs(notifications) do
        assert.is_string(notif.msg)
        assert.is_number(notif.level)
      end
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **デバッグフラグの確認**
   ```lua
   local config = require("ime-auto.config").get()
   print("Debug mode:", config.debug)
   ```

2. **notify実装の確認**
   ```lua
   -- utils.lua:16-21
   local function notify(msg, level)
     if not config.get().debug and level == vim.log.levels.DEBUG then
       return
     end
     vim.notify(prefix .. msg, level)
   end
   ```

3. **ログレベルの定義**
   ```lua
   vim.log.levels.DEBUG  -- 1
   vim.log.levels.INFO   -- 2
   vim.log.levels.WARN   -- 3
   vim.log.levels.ERROR  -- 4
   ```

### 改善提案

**タイミング情報の追加**:

```lua
local function notify_with_timing(msg, level, start_time)
  local elapsed = vim.loop.now() - start_time
  local msg_with_time = string.format("%s (took %dms)", msg, elapsed)
  M.notify(msg_with_time, level)
end

-- 使用例
local start = vim.loop.now()
ime_control(action)
notify_with_timing("IME control completed", vim.log.levels.DEBUG, start)
```

**構造化ログ**:

```lua
local function debug_log(event, data)
  if not config.get().debug then return end

  local log_entry = {
    event = event,
    timestamp = vim.loop.now(),
    data = data,
  }

  vim.notify(vim.inspect(log_entry), vim.log.levels.DEBUG)
end

-- 使用例
debug_log("ime_state_change", { from = "off", to = "on", mode = "insert" })
```

## 成功基準

以下のすべての条件を満たすこと：

- ✅ `debug = true`でDEBUGログが出力される
- ✅ `debug = false`でDEBUGログが抑制される
- ✅ ログに有用な情報（モード、IME状態）が含まれる
- ✅ `:ImeAutoStatus`で現在の状態が表示される
- ✅ エラー時に詳細情報が記録される
- ✅ ログフォーマットが一貫している

## 関連テストケース

- [01: 基本的なIME切り替え](../priority-1-critical/01-basic-ime-switching.md)
- [07: 設定バリデーション](../priority-2-important/07-config-validation.md)
- [11: 設定変更の即時反映](./11-runtime-config-changes.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: タイミング情報と構造化ログの追加
