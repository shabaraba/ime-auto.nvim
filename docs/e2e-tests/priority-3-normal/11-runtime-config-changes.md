# テストケース 11: 設定変更の即時反映

**優先度**: Priority 3 - Normal
**カテゴリ**: 設定管理・動的変更
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、プラグイン実行中に設定を変更した際に、変更が即座に反映されることを検証します。

### テストの重要性

- ✅ **ユーザービリティ**: 再起動なしで設定変更可能
- ✅ **開発者体験**: 設定のテスト・調整が容易
- ✅ **動的設定**: 条件に応じた設定変更が可能

## 関連ファイル

- `/lua/ime-auto/config.lua` (L16-28: setup実装)
- `/lua/ime-auto/escape.lua` (設定依存の動作)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
```

## テストステップ

### Test 11.1: escape_sequenceの動的変更

**手順**:

1. デフォルト設定（`ｋｊ`）で起動
2. エスケープシーケンス動作確認
3. `escape_sequence = "ｊｊ"`に変更
4. 新しいエスケープシーケンスが動作することを確認
5. 古いエスケープシーケンスが無効になることを確認

**期待される結果**:

- 新しい`ｊｊ`でNormalモード移行
- 古い`ｋｊ`では移行しない

**検証ポイント**:

```lua
-- 初期設定
require("ime-auto").setup({
  escape_sequence = "ｋｊ",
})

vim.cmd("startinsert")
vim.fn.feedkeys("testｋｊ", "nx")
vim.wait(300)

-- ｋｊで移行
assert.equals("n", vim.api.nvim_get_mode().mode)
assert.equals("test", vim.api.nvim_get_current_line())

-- 設定変更
require("ime-auto").setup({
  escape_sequence = "ｊｊ",
})

-- エスケープモジュールの再初期化が必要
local escape = require("ime-auto.escape")
escape.setup()

vim.cmd("enew")
vim.cmd("startinsert")

-- 新しいｊｊで移行
vim.fn.feedkeys("newｊｊ", "nx")
vim.wait(300)

assert.equals("n", vim.api.nvim_get_mode().mode)
assert.equals("new", vim.api.nvim_get_current_line())

-- 古いｋｊは無効
vim.cmd("enew")
vim.cmd("startinsert")
vim.fn.feedkeys("oldｋｊ", "nx")
vim.wait(300)

-- まだInsertモード（エスケープされない）
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.cmd("stopinsert")
```

---

### Test 11.2: escape_timeoutの動的変更

**手順**:

1. `escape_timeout = 200` で起動
2. `ｋ`入力後、250ms待機してから`ｊ`入力
3. タイムアウトでエスケープシーケンス無効確認
4. `escape_timeout = 500`に変更
5. 同じテストでタイムアウトしないことを確認

**期待される結果**:

- timeout=200: 250ms後の`ｊ`では反応しない
- timeout=500: 250ms後の`ｊ`で反応する

**検証ポイント**:

```lua
-- 初期設定: timeout=200
require("ime-auto").setup({
  escape_timeout = 200,
})

local escape = require("ime-auto.escape")
escape.setup()

vim.cmd("startinsert")

-- ｋ入力
vim.fn.feedkeys("ｋ", "nx")

-- 250ms待機（timeout超過）
vim.wait(250)

-- ｊ入力
vim.fn.feedkeys("ｊ", "nx")
vim.wait(100)

-- タイムアウトでエスケープされない
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.cmd("stopinsert")
vim.cmd("enew")

-- 設定変更: timeout=500
require("ime-auto").setup({
  escape_timeout = 500,
})
escape.setup()

vim.cmd("startinsert")

-- ｋ入力
vim.fn.feedkeys("ｋ", "nx")

-- 250ms待機（timeout内）
vim.wait(250)

-- ｊ入力
vim.fn.feedkeys("ｊ", "nx")
vim.wait(100)

-- エスケープされる
assert.equals("n", vim.api.nvim_get_mode().mode)
```

---

### Test 11.3: debugモードの動的切り替え

**手順**:

1. `debug = false`で起動
2. デバッグログが出力されないことを確認
3. `debug = true`に変更
4. デバッグログが出力されることを確認

**期待される結果**:

- debug=false: DEBUGレベルのログなし
- debug=true: DEBUGレベルのログあり

**検証ポイント**:

```lua
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

-- 初期設定: debug=false
require("ime-auto").setup({
  debug = false,
})

notifications = {}

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(100)

-- DEBUGログなし
local debug_count = 0
for _, n in ipairs(notifications) do
  if n.level == vim.log.levels.DEBUG then
    debug_count = debug_count + 1
  end
end

assert.equals(0, debug_count)

-- 設定変更: debug=true
require("ime-auto").setup({
  debug = true,
})

notifications = {}

vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(100)

-- DEBUGログあり
debug_count = 0
for _, n in ipairs(notifications) do
  if n.level == vim.log.levels.DEBUG then
    debug_count = debug_count + 1
  end
end

assert.is_true(debug_count > 0)

vim.notify = original_notify
```

---

### Test 11.4: custom_commandsの動的変更

**手順**:

1. カスタムコマンドなしで起動
2. カスタムコマンドを設定
3. カスタムコマンドが実行されることを確認

**期待される結果**:

- カスタムコマンド設定後、即座に使用される

**検証ポイント**:

```lua
-- 初期設定: builtin
require("ime-auto").setup({
  ime_method = "builtin",
})

-- カスタムコマンドに変更
local log_file = vim.fn.tempname()

require("ime-auto").setup({
  ime_method = "custom",
  custom_commands = {
    on = string.format("echo 'on' >> %s", log_file),
    off = string.format("echo 'off' >> %s", log_file),
    status = "echo '1'",
  },
})

local ime = require("ime-auto.ime")

-- カスタムコマンド実行
ime.on()
vim.wait(100)

ime.off()
vim.wait(100)

-- ログファイル確認
local lines = vim.fn.readfile(log_file)
assert.is_true(#lines >= 2)

vim.fn.delete(log_file)
```

---

### Test 11.5: 設定変更後のプラグイン動作確認

**手順**:

1. デフォルト設定で起動
2. 複数の設定を同時変更
3. プラグイン全体が正常動作することを確認

**期待される結果**:

- 設定変更後もエラーなく動作
- すべての変更が反映される

**検証ポイント**:

```lua
-- 初期設定
require("ime-auto").setup({
  escape_sequence = "ｋｊ",
  escape_timeout = 200,
  debug = false,
})

-- 複数設定を一度に変更
require("ime-auto").setup({
  escape_sequence = "ｊｋ",
  escape_timeout = 300,
  debug = true,
})

local escape = require("ime-auto.escape")
escape.setup()

-- 動作確認
vim.cmd("startinsert")

vim.fn.feedkeys("testｊｋ", "nx")
vim.wait(400)

-- 新しいエスケープシーケンスで動作
assert.equals("n", vim.api.nvim_get_mode().mode)
assert.equals("test", vim.api.nvim_get_current_line())
```

---

### Test 11.6: 設定変更時の既存状態への影響

**手順**:

1. InsertモードでIME=ON
2. 設定変更
3. 保存されていたIME状態が維持されることを確認

**期待される結果**:

- 設定変更は新しい操作にのみ影響
- 既存のIME状態は保持される

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")
local config = require("ime-auto.config").get()

if config.os == "macos" then
  pending("macOS uses slot-based system")
  return
end

-- InsertモードでIME=ON
vim.cmd("startinsert")
ime.on()
vim.wait(50)

local before_change = ime.get_status()
assert.is_true(before_change)

vim.cmd("stopinsert")
vim.wait(100)

-- 設定変更（IME状態に影響しない設定）
require("ime-auto").setup({
  escape_timeout = 300,
})

-- IME状態が維持されているか
vim.cmd("startinsert")
vim.wait(50)

local after_change = ime.get_status()
assert.equals(before_change, after_change)

vim.cmd("stopinsert")
```

## 実装例

```lua
-- tests/priority-3/runtime_config_changes_spec.lua
local ime_auto = require("ime-auto")

describe("Test 11: Runtime config changes", function()
  before_each(function()
    vim.cmd("enew!")
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("11.1: escape_sequenceの動的変更", function()
    it("should apply new escape sequence", function()
      ime_auto.setup({ escape_sequence = "ｋｊ" })

      vim.cmd("startinsert")
      vim.fn.feedkeys("testｋｊ", "nx")
      vim.wait(300)

      assert.equals("n", vim.api.nvim_get_mode().mode)
      assert.equals("test", vim.api.nvim_get_current_line())

      -- 設定変更
      ime_auto.setup({ escape_sequence = "ｊｊ" })
      local escape = require("ime-auto.escape")
      escape.setup()

      vim.cmd("enew")
      vim.cmd("startinsert")
      vim.fn.feedkeys("newｊｊ", "nx")
      vim.wait(300)

      assert.equals("n", vim.api.nvim_get_mode().mode)
      assert.equals("new", vim.api.nvim_get_current_line())
    end)
  end)

  describe("11.2: escape_timeoutの動的変更", function()
    it("should apply new timeout value", function()
      ime_auto.setup({ escape_timeout = 200 })
      local escape = require("ime-auto.escape")
      escape.setup()

      vim.cmd("startinsert")
      vim.fn.feedkeys("ｋ", "nx")
      vim.wait(250)
      vim.fn.feedkeys("ｊ", "nx")
      vim.wait(100)

      assert.equals("i", vim.api.nvim_get_mode().mode)

      vim.cmd("stopinsert")
      vim.cmd("enew")

      -- timeout延長
      ime_auto.setup({ escape_timeout = 500 })
      escape.setup()

      vim.cmd("startinsert")
      vim.fn.feedkeys("ｋ", "nx")
      vim.wait(250)
      vim.fn.feedkeys("ｊ", "nx")
      vim.wait(100)

      assert.equals("n", vim.api.nvim_get_mode().mode)
    end)
  end)

  describe("11.3: debugモードの動的切り替え", function()
    it("should enable/disable debug logs", function()
      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
        original_notify(msg, level)
      end

      ime_auto.setup({ debug = false })
      notifications = {}

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(100)

      local debug_count = 0
      for _, n in ipairs(notifications) do
        if n.level == vim.log.levels.DEBUG then
          debug_count = debug_count + 1
        end
      end

      assert.equals(0, debug_count)

      ime_auto.setup({ debug = true })
      notifications = {}

      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(100)

      debug_count = 0
      for _, n in ipairs(notifications) do
        if n.level == vim.log.levels.DEBUG then
          debug_count = debug_count + 1
        end
      end

      assert.is_true(debug_count > 0)

      vim.notify = original_notify
    end)
  end)

  describe("11.5: 複数設定の同時変更", function()
    it("should handle multiple config changes", function()
      ime_auto.setup({
        escape_sequence = "ｋｊ",
        escape_timeout = 200,
        debug = false,
      })

      ime_auto.setup({
        escape_sequence = "ｊｋ",
        escape_timeout = 300,
        debug = true,
      })

      local escape = require("ime-auto.escape")
      escape.setup()

      vim.cmd("startinsert")
      vim.fn.feedkeys("testｊｋ", "nx")
      vim.wait(400)

      assert.equals("n", vim.api.nvim_get_mode().mode)
      assert.equals("test", vim.api.nvim_get_current_line())
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **設定の上書き動作**
   ```lua
   -- config.lua:16-28
   M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
   ```

2. **escape.setup()の再呼び出し**
   - `escape_sequence`や`escape_timeout`変更時は`escape.setup()`が必要
   - オートコマンドの再登録

3. **キャッシュのクリア**
   - 設定変更後、キャッシュがクリアされているか確認

### 改善提案

**設定変更の自動反映**:

```lua
function M.setup(opts)
  M.config.setup(opts)

  -- エスケープシーケンス関連の設定が変わった場合、自動で再初期化
  if opts.escape_sequence or opts.escape_timeout then
    M.escape.setup()
  end

  -- キャッシュクリア
  M.ime.clear_cache()
end
```

## 成功基準

以下のすべての条件を満たすこと：

- ✅ `escape_sequence`の動的変更が反映される
- ✅ `escape_timeout`の動的変更が反映される
- ✅ `debug`モードの切り替えが即座に反映される
- ✅ `custom_commands`の動的変更が反映される
- ✅ 複数設定の同時変更が正常動作する
- ✅ 既存のIME状態が設定変更で破壊されない

## 関連テストケース

- [01: 基本的なIME切り替え](../priority-1-critical/01-basic-ime-switching.md)
- [07: 設定バリデーション](../priority-2-important/07-config-validation.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: 設定変更時の自動再初期化機構
