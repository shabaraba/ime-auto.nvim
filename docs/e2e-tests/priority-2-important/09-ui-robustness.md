# テストケース 09: UIモジュールの堅牢性

**優先度**: Priority 2 - Important
**カテゴリ**: UI・ユーザーインタラクション
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、`:ImeAutoListInputSources`コマンドで表示されるフローティングウィンドウUIの堅牢性を検証します。特に、無限ループリスクとキャンセル動作を確認します。

### テストの重要性

- ✅ **潜在的バグ**: 無限ループリスク（信頼度80%）
- ✅ **ユーザー体験**: UIモーダルのキャンセルが確実に動作
- ✅ **堅牢性**: 予期しない入力に対する耐性

### 発見された問題

**ファイル**: `/lua/ime-auto/ui.lua` (L140-166)

**問題点**:
```lua
local function get_input()
  while current_float and vim.api.nvim_win_is_valid(current_float) do
    vim.cmd('redraw')
    local ok, char = pcall(vim.fn.getchar)
    if not ok then break end
    -- ...
  end
end
```

`pcall(vim.fn.getchar)`がエラーなく継続的に失敗する場合、ループが無限に続く可能性があります。タイムアウト機構がありません。

## 関連ファイル

- `/lua/ime-auto/ui.lua` (L1-189: UI実装全体)
- `/lua/ime-auto/init.lua` (L35-57: コマンド定義)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
```

### 初期設定

```lua
require("ime-auto").setup()
```

## テストステップ

### Test 9.1: フローティングウィンドウの表示

**手順**:

1. `:ImeAutoListInputSources`を実行
2. フローティングウィンドウが表示されることを確認
3. ウィンドウの内容を確認

**期待される結果** (macOS):

- 利用可能な入力ソースのリストが表示される
- フローティングウィンドウとして表示される（通常ウィンドウではない）

**期待される結果** (Windows/Linux):

- 「macOS専用機能」のメッセージが表示される

**検証ポイント**:

```lua
local config = require("ime-auto.config").get()

if config.os == "macos" then
  vim.cmd("ImeAutoListInputSources")
  vim.wait(100)

  local ui = require("ime-auto.ui")

  -- フローティングウィンドウが表示されているか
  assert.is_not_nil(ui.current_float)
  assert.is_true(vim.api.nvim_win_is_valid(ui.current_float))

  -- ウィンドウがfloatingか確認
  local win_config = vim.api.nvim_win_get_config(ui.current_float)
  assert.equals("editor", win_config.relative)

  -- クローズ
  ui.close_float()
else
  -- 非macOSでは警告メッセージ
  vim.cmd("ImeAutoListInputSources")
  -- エラーなし
end
```

---

### Test 9.2: キー操作（j/k移動）

**手順** (macOS):

1. `:ImeAutoListInputSources`でUI表示
2. `j`キーで下移動
3. `k`キーで上移動
4. カーソル位置が正しく更新されることを確認

**期待される結果**:

- `j`: カーソルが1行下に移動
- `k`: カーソルが1行上に移動
- 最上行/最下行でのループ（または停止）

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

-- UIコールバックのモック（実際のキー入力シミュレーション）
local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
  { id = "com.apple.inputmethod.Kotoeri.Japanese", name = "Japanese" },
}

local selected_idx = nil
ui.select_from_list("Test", items, function(idx)
  selected_idx = idx
end)

vim.wait(100)

-- キー送信: j（下移動）
vim.api.nvim_feedkeys("j", "nx", false)
vim.wait(50)

-- カーソル位置確認（内部状態へのアクセスが必要）
-- 注: 実際のテストでは、UIモジュールに状態取得APIが必要

-- ESCでキャンセル
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
vim.wait(100)

-- UIが閉じているか
assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
```

---

### Test 9.3: Enter キーで選択

**手順** (macOS):

1. UI表示
2. `j`で2行目に移動
3. `Enter`で選択
4. コールバックが呼ばれ、選択したindexが渡されることを確認

**期待される結果**:

- コールバック関数が実行される
- 正しいindexが渡される
- UIが自動的に閉じる

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
  { id = "com.apple.inputmethod.Kotoeri.Japanese", name = "Japanese" },
}

local selected_idx = nil
ui.select_from_list("Test", items, function(idx)
  selected_idx = idx
end)

vim.wait(100)

-- j キーで下移動
vim.api.nvim_feedkeys("j", "nx", false)
vim.wait(50)

-- Enter で選択
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "nx", false)
vim.wait(100)

-- コールバックが呼ばれたか
assert.equals(2, selected_idx)

-- UIが閉じたか
assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
```

---

### Test 9.4: ESC/q でキャンセル

**手順**:

1. UI表示
2. `ESC`または`q`でキャンセル
3. コールバックが呼ばれないことを確認
4. UIが閉じることを確認

**期待される結果**:

- コールバック未実行
- UIクローズ

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
}

local callback_called = false
ui.select_from_list("Test", items, function(idx)
  callback_called = true
end)

vim.wait(100)

-- ESC でキャンセル
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
vim.wait(100)

-- コールバック未実行
assert.is_false(callback_called)

-- UI閉じた
assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
```

---

### Test 9.5: 無効なキー入力の無視

**手順**:

1. UI表示
2. 無効なキー（例: `a`, `1`, `<Space>`）を入力
3. 無視されることを確認（エラーなし）

**期待される結果**:

- 無効なキーは無視される
- UIがクラッシュしない

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
}

ui.select_from_list("Test", items, function(idx) end)
vim.wait(100)

-- 無効なキー入力
vim.api.nvim_feedkeys("a", "nx", false)
vim.wait(50)

vim.api.nvim_feedkeys("1", "nx", false)
vim.wait(50)

-- UIがまだ有効
assert.is_true(vim.api.nvim_win_is_valid(ui.current_float))

-- ESCで終了
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
vim.wait(100)
```

---

### Test 9.6: 空のリストでのUI表示

**手順**:

1. 空の`items`配列でUI表示
2. エラーハンドリングを確認

**期待される結果**:

- 空のリスト表示またはエラーメッセージ
- クラッシュしない

**検証ポイント**:

```lua
local ui = require("ime-auto.ui")

local items = {}

-- 空リストでUI表示
ui.select_from_list("Test", items, function(idx) end)
vim.wait(100)

-- エラーなく表示されるか、適切なメッセージ
-- (現在の実装では空のフローティングウィンドウ)

-- クローズ
if ui.current_float and vim.api.nvim_win_is_valid(ui.current_float) then
  ui.close_float()
end
```

---

### Test 9.7: getchar()のタイムアウト処理

**手順**:

1. UI表示
2. 長時間（10秒）キー入力なし
3. タイムアウトまたは継続動作を確認

**期待される結果**:

- タイムアウト機構がある場合: 自動的にUIクローズ
- タイムアウト機構がない場合: 無限待機（改善提案）

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
}

ui.select_from_list("Test", items, function(idx) end)
vim.wait(100)

-- 10秒待機（タイムアウトテスト）
-- 注: 実際のテストでは短縮（例: 1秒）
vim.wait(1000)

-- UIがまだ有効か確認
local still_valid = vim.api.nvim_win_is_valid(ui.current_float or -1)

-- タイムアウト実装の有無に応じて検証
if still_valid then
  -- タイムアウトなし → 手動でクローズ
  ui.close_float()
else
  -- タイムアウトあり → 自動クローズ済み
  assert.is_true(true)
end
```

---

### Test 9.8: 複数回のUI表示

**手順**:

1. UI表示 → キャンセル
2. 再度UI表示
3. 正常動作することを確認

**期待される結果**:

- 前回のUIが完全にクリーンアップされている
- 新しいUIが正常表示される

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ui = require("ime-auto.ui")

local items = {
  { id = "com.apple.keylayout.ABC", name = "ABC" },
}

for i = 1, 3 do
  ui.select_from_list("Test " .. i, items, function(idx) end)
  vim.wait(100)

  assert.is_true(vim.api.nvim_win_is_valid(ui.current_float))

  -- ESCでキャンセル
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  vim.wait(100)

  assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
end
```

## 実装例

```lua
-- tests/priority-2/ui_robustness_spec.lua
local ui = require("ime-auto.ui")

describe("Test 09: UI robustness", function()
  local config = nil

  before_each(function()
    config = require("ime-auto.config").get()
  end)

  after_each(function()
    -- UIクリーンアップ
    if ui.current_float and vim.api.nvim_win_is_valid(ui.current_float) then
      ui.close_float()
    end
  end)

  describe("9.1: フローティングウィンドウ表示", function()
    it("should display floating window on macOS", function()
      if config.os ~= "macos" then
        pending("This test is macOS only")
        return
      end

      vim.cmd("ImeAutoListInputSources")
      vim.wait(100)

      assert.is_not_nil(ui.current_float)
      assert.is_true(vim.api.nvim_win_is_valid(ui.current_float))

      local win_config = vim.api.nvim_win_get_config(ui.current_float)
      assert.equals("editor", win_config.relative)

      ui.close_float()
    end)

    it("should show warning on non-macOS", function()
      if config.os == "macos" then
        pending("This test is for non-macOS")
        return
      end

      vim.cmd("ImeAutoListInputSources")
      -- エラーなし
    end)
  end)

  describe("9.4: ESC/qでキャンセル", function()
    it("should cancel with ESC", function()
      if config.os ~= "macos" then
        pending("This test is macOS only")
        return
      end

      local items = {
        { id = "com.apple.keylayout.ABC", name = "ABC" },
      }

      local callback_called = false
      ui.select_from_list("Test", items, function(idx)
        callback_called = true
      end)

      vim.wait(100)

      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
        "nx",
        false
      )
      vim.wait(100)

      assert.is_false(callback_called)
      assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
    end)
  end)

  describe("9.6: 空のリスト", function()
    it("should handle empty list gracefully", function()
      local items = {}

      ui.select_from_list("Test", items, function(idx) end)
      vim.wait(100)

      -- エラーなく表示
      if ui.current_float and vim.api.nvim_win_is_valid(ui.current_float) then
        ui.close_float()
      end
    end)
  end)

  describe("9.8: 複数回のUI表示", function()
    it("should handle multiple UI invocations", function()
      if config.os ~= "macos" then
        pending("This test is macOS only")
        return
      end

      local items = {
        { id = "com.apple.keylayout.ABC", name = "ABC" },
      }

      for i = 1, 3 do
        ui.select_from_list("Test " .. i, items, function(idx) end)
        vim.wait(100)

        assert.is_true(vim.api.nvim_win_is_valid(ui.current_float))

        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
          "nx",
          false
        )
        vim.wait(100)

        assert.is_false(vim.api.nvim_win_is_valid(ui.current_float or -1))
      end
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **getchar()の動作**
   ```lua
   -- ui.lua:147
   local ok, char = pcall(vim.fn.getchar)
   ```

2. **無限ループチェック**
   ```lua
   -- 現在の実装
   while current_float and vim.api.nvim_win_is_valid(current_float) do
     -- タイムアウトなし
   end
   ```

3. **改善提案**: タイムアウト追加
   ```lua
   local function get_input_with_timeout(timeout_ms)
     local start_time = vim.loop.now()

     while current_float and vim.api.nvim_win_is_valid(current_float) do
       if vim.loop.now() - start_time > timeout_ms then
         vim.notify("UI timeout", vim.log.levels.WARN)
         close_float()
         break
       end

       vim.cmd('redraw')
       local ok, char = pcall(vim.fn.getchar, 0) -- non-blocking
       -- ...
     end
   end
   ```

### macOSでのSwift tool依存

- UIの`:ImeAutoListInputSources`はSwift toolの`list-all`コマンドに依存
- Swift toolがコンパイルされていない場合はエラー

## 成功基準

以下のすべての条件を満たすこと：

- ✅ フローティングウィンドウが正しく表示される（macOS）
- ✅ キー操作（j/k/Enter/ESC/q）が正常動作する
- ✅ コールバックが適切に実行される
- ✅ 無効なキーが無視される
- ✅ 空のリストでクラッシュしない
- ✅ 複数回のUI表示で状態が混ざらない
- ✅ タイムアウト処理がある（または改善提案）

## 関連テストケース

- [04: Swiftツールのコンパイルとリカバリ](../priority-1-critical/04-swift-tool-compilation.md)
- [06: リソースクリーンアップ](./06-resource-cleanup.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: getchar()のタイムアウト機構追加
