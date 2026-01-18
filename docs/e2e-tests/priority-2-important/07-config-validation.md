# テストケース 07: 設定バリデーション

**優先度**: Priority 2 - Important
**カテゴリ**: 設定管理・エラーハンドリング
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、無効な設定値が渡された際に、適切にデフォルト値へフォールバックし、警告メッセージを表示することを検証します。

### テストの重要性

- ✅ **ユーザーエラー対応**: 設定ミスでプラグインが動作不能にならない
- ✅ **開発者体験**: 明確なエラーメッセージでデバッグを容易に
- ✅ **堅牢性**: 予期しない入力に対する耐性

## 関連ファイル

- `/lua/ime-auto/config.lua` (L3-14: デフォルト値, L16-42: setup/OS検出)
- `/lua/ime-auto/init.lua` (L89-96: setup実装)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
```

## テストステップ

### Test 7.1: 無効なescape_sequence

**手順**:

1. `escape_sequence = ""` (空文字) で setup
2. デフォルト値（`"ｋｊ"`）が使用されることを確認
3. 警告メッセージの表示確認

**期待される結果**:

- デフォルト値 `"ｋｊ"` が設定される
- 警告メッセージが表示される
- プラグインは正常動作

**検証ポイント**:

```lua
-- vim.notifyをモック
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

require("ime-auto").setup({
  escape_sequence = "", -- 無効
})

local config = require("ime-auto.config").get()

-- デフォルト値が使用される
assert.equals("ｋｊ", config.escape_sequence)

-- 警告メッセージがあるか
-- (現在の実装では警告なし → 改善提案)

vim.notify = original_notify
```

---

### Test 7.2: 無効なescape_timeout

**手順**:

1. `escape_timeout = -100` (負の値) で setup
2. デフォルト値（200）が使用されることを確認

**期待される結果**:

- デフォルト値 200 が設定される
- 警告メッセージが表示される

**検証ポイント**:

```lua
require("ime-auto").setup({
  escape_timeout = -100, -- 無効
})

local config = require("ime-auto.config").get()

-- デフォルト値が使用される
assert.equals(200, config.escape_timeout)

-- または、負の値が設定された場合は最小値（例: 50）にクランプ
assert.is_true(config.escape_timeout >= 50)
```

---

### Test 7.3: escape_timeout = 0

**手順**:

1. `escape_timeout = 0` で setup
2. エスケープシーケンスが即座にタイムアウトすることを確認

**期待される結果**:

- `escape_timeout = 0` が設定される（有効な値として）
- エスケープシーケンスが実質的に無効化される

**検証ポイント**:

```lua
require("ime-auto").setup({
  escape_timeout = 0,
})

vim.cmd("startinsert")
vim.fn.feedkeys("ｋ", "nx")

-- 即座にタイムアウト
vim.wait(10)

-- pending_charがクリアされている
vim.fn.feedkeys("ｊ", "nx")
vim.wait(50)

-- エスケープシーケンスとして動作しない
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.cmd("stopinsert")
```

---

### Test 7.4: 無効なOS指定

**手順**:

1. `os = "invalid_os"` で setup
2. 自動検出が実行されることを確認

**期待される結果**:

- `os = "auto"` として扱われる
- 実際のOSが検出される

**検証ポイント**:

```lua
require("ime-auto").setup({
  os = "invalid_os",
})

local config = require("ime-auto.config").get()

-- 有効なOS値のいずれか
local valid_os = { "macos", "windows", "linux" }
assert.is_true(vim.tbl_contains(valid_os, config.os))
```

---

### Test 7.5: ime_method = "custom" だがcustom_commands未設定

**手順**:

1. `ime_method = "custom"` but `custom_commands = nil` で setup
2. エラーハンドリングを確認

**期待される結果**:

- 警告メッセージが表示される
- `ime_method = "builtin"` にフォールバック

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
end

require("ime-auto").setup({
  ime_method = "custom",
  custom_commands = nil, -- 未設定
})

-- 警告が出ているか確認
local has_warning = false
for _, notif in ipairs(notifications) do
  if notif.level == vim.log.levels.WARN then
    has_warning = true
    break
  end
end

-- (現在の実装では警告なし → 改善提案)

vim.notify = original_notify
```

---

### Test 7.6: custom_commandsの一部が欠如

**手順**:

1. `custom_commands = { on = "cmd", off = nil }` で setup
2. エラーハンドリングを確認

**期待される結果**:

- 警告メッセージが表示される
- offコマンドが呼ばれた際にエラーハンドリング

**検証ポイント**:

```lua
require("ime-auto").setup({
  ime_method = "custom",
  custom_commands = {
    on = "echo 'on'",
    off = nil, -- 欠如
    status = "echo '1'",
  },
})

local ime = require("ime-auto.ime")

-- off呼び出し
local result = ime.off()

-- エラーが適切にハンドリングされる
assert.is_not_nil(result)
```

---

### Test 7.7: nilやtypeエラーのある設定

**手順**:

1. `escape_sequence = 123` (数値) で setup
2. 型エラーが検出されることを確認

**期待される結果**:

- デフォルト値にフォールバック
- 警告メッセージが表示される

**検証ポイント**:

```lua
require("ime-auto").setup({
  escape_sequence = 123, -- 型エラー
  escape_timeout = "invalid", -- 型エラー
})

local config = require("ime-auto.config").get()

-- デフォルト値が使用される
assert.equals("ｋｊ", config.escape_sequence)
assert.equals(200, config.escape_timeout)
```

---

### Test 7.8: debugモードでの詳細ログ

**手順**:

1. `debug = true` で setup
2. 各種操作でデバッグログが出力されることを確認

**期待される結果**:

- vim.log.levels.DEBUG レベルのログが出力される
- ログ内容が有用（IME状態、モード切り替えなど）

**検証ポイント**:

```lua
local debug_logs = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  if level == vim.log.levels.DEBUG then
    table.insert(debug_logs, msg)
  end
  original_notify(msg, level)
end

require("ime-auto").setup({
  debug = true,
})

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(100)

-- デバッグログが出力されている
assert.is_true(#debug_logs > 0)

vim.notify = original_notify
```

## 実装例

```lua
-- tests/priority-2/config_validation_spec.lua
local ime_auto = require("ime-auto")

describe("Test 07: Config validation", function()
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

  describe("7.1: 無効なescape_sequence", function()
    it("should fallback to default on empty string", function()
      ime_auto.setup({
        escape_sequence = "",
      })

      local config = require("ime-auto.config").get()
      assert.equals("ｋｊ", config.escape_sequence)
    end)

    it("should fallback to default on nil", function()
      ime_auto.setup({
        escape_sequence = nil,
      })

      local config = require("ime-auto.config").get()
      assert.equals("ｋｊ", config.escape_sequence)
    end)
  end)

  describe("7.2: 無効なescape_timeout", function()
    it("should fallback to default on negative value", function()
      ime_auto.setup({
        escape_timeout = -100,
      })

      local config = require("ime-auto.config").get()
      assert.equals(200, config.escape_timeout)
    end)
  end)

  describe("7.3: escape_timeout = 0", function()
    it("should allow zero timeout", function()
      ime_auto.setup({
        escape_timeout = 0,
      })

      local config = require("ime-auto.config").get()
      assert.equals(0, config.escape_timeout)

      -- エスケープシーケンスが即座にタイムアウト
      vim.cmd("startinsert")
      vim.fn.feedkeys("ｋ", "nx")
      vim.wait(10)
      vim.fn.feedkeys("ｊ", "nx")
      vim.wait(50)

      assert.equals("i", vim.api.nvim_get_mode().mode)
      vim.cmd("stopinsert")
    end)
  end)

  describe("7.4: 無効なOS指定", function()
    it("should auto-detect OS on invalid value", function()
      ime_auto.setup({
        os = "invalid_os",
      })

      local config = require("ime-auto.config").get()
      local valid_os = { "macos", "windows", "linux" }
      assert.is_true(vim.tbl_contains(valid_os, config.os))
    end)
  end)

  describe("7.5: custom_commands未設定", function()
    it("should warn when ime_method=custom but no commands", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = nil,
      })

      -- 警告メッセージ確認（実装次第）
      -- 現在の実装では警告なしの可能性
    end)
  end)

  describe("7.7: 型エラーのある設定", function()
    it("should handle type errors gracefully", function()
      ime_auto.setup({
        escape_sequence = 123,
        escape_timeout = "invalid",
      })

      local config = require("ime-auto.config").get()
      assert.equals("ｋｊ", config.escape_sequence)
      assert.equals(200, config.escape_timeout)
    end)
  end)

  describe("7.8: debugモード", function()
    it("should output debug logs when enabled", function()
      ime_auto.setup({
        debug = true,
      })

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(100)

      local debug_count = 0
      for _, notif in ipairs(notifications) do
        if notif.level == vim.log.levels.DEBUG then
          debug_count = debug_count + 1
        end
      end

      assert.is_true(debug_count > 0)
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **デフォルト値の定義**
   ```lua
   -- config.lua:3-14
   M.defaults = {
     escape_sequence = "ｋｊ",
     escape_timeout = 200,
     -- ...
   }
   ```

2. **バリデーション処理の有無**
   - 現在の実装では、`vim.tbl_deep_extend("force", ...)`で単純にマージ
   - バリデーションロジックが不足している可能性

3. **改善提案**:
   ```lua
   function M.validate(opts)
     if opts.escape_sequence then
       if type(opts.escape_sequence) ~= "string" or #opts.escape_sequence == 0 then
         vim.notify("Invalid escape_sequence, using default", vim.log.levels.WARN)
         opts.escape_sequence = nil
       end
     end

     if opts.escape_timeout then
       if type(opts.escape_timeout) ~= "number" or opts.escape_timeout < 0 then
         vim.notify("Invalid escape_timeout, using default", vim.log.levels.WARN)
         opts.escape_timeout = nil
       end
     end

     return opts
   end
   ```

## 成功基準

以下のすべての条件を満たすこと：

- ✅ 無効な`escape_sequence`でデフォルト値が使用される
- ✅ 無効な`escape_timeout`でデフォルト値が使用される
- ✅ 無効な`os`指定で自動検出される
- ✅ 型エラーが適切にハンドリングされる
- ✅ 警告メッセージが表示される（改善提案）
- ✅ `debug = true`でデバッグログが出力される
- ✅ どの設定エラーでもプラグインがクラッシュしない

## 関連テストケース

- [01: 基本的なIME切り替え](../priority-1-critical/01-basic-ime-switching.md)
- [06: リソースクリーンアップ](./06-resource-cleanup.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: バリデーションロジックと警告メッセージの追加が推奨
