# テストケース 01: 基本的なIME切り替え

**優先度**: Priority 1 - Critical
**カテゴリ**: コア機能
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、ime-auto.nvimの最も基本的な機能である、モード切り替え時の自動IME制御を検証します。

### テストの重要性

- ✅ プラグインの存在意義となるコア機能
- ✅ ユーザーが最も頻繁に使用する動作パターン
- ✅ 他のすべての機能の基盤となる

### 検証する機能

1. **InsertEnter時のIME復元**
2. **InsertLeave時のIME OFF**
3. **エスケープシーケンス(`ｋｊ`)によるNormalモード移行**
4. **エスケープシーケンス入力時の文字削除**

## 関連ファイル

- `/lua/ime-auto/init.lua` (L11-33: オートコマンド定義)
- `/lua/ime-auto/escape.lua` (L14-77: エスケープシーケンス処理)
- `/lua/ime-auto/ime.lua` (L141-216: IME制御とstate管理)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
-- OS: macOS, Windows, または Linux
-- テストフレームワーク: plenary.nvim
```

### 初期設定

```lua
require("ime-auto").setup({
  escape_sequence = "ｋｊ",
  escape_timeout = 200,
  debug = false,
})
```

## テストステップ

### Test 1.1: InsertEnter時のIME復元

**手順**:

1. Normalモードで開始
2. IME状態を確認（OFF想定）
3. `i`でInsertモード開始
4. IME状態を確認（前回の状態が復元される）

**期待される結果**:

- InsertEnter時に`ime.restore_state()`が呼ばれる
- 前回InsertモードでIME=ONだった場合、ONに復元される
- 前回InsertモードでIME=OFFだった場合、OFFのまま

**検証ポイント**:

```lua
-- オートコマンドが正しく登録されているか
local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
assert(#autocmds > 0, "ime_auto autocmds should be registered")

-- InsertEnterでコールバックが実行されるか
local insert_enter_autocmd = vim.tbl_filter(function(cmd)
  return cmd.event == "InsertEnter"
end, autocmds)
assert(#insert_enter_autocmd == 1, "InsertEnter autocmd should exist")
```

---

### Test 1.2: InsertLeave時のIME OFF

**手順**:

1. Insertモード開始
2. IMEをONに切り替え（手動または自動復元）
3. `<Esc>`でNormalモードに戻る
4. IME状態を確認（OFFになっているはず）

**期待される結果**:

- InsertLeave時に`ime.off()`が呼ばれる
- IMEが確実にOFFになる
- 状態が保存される

**検証ポイント**:

```lua
-- InsertLeaveでコールバックが実行されるか
local insert_leave_autocmd = vim.tbl_filter(function(cmd)
  return cmd.event == "InsertLeave"
end, autocmds)
assert(#insert_leave_autocmd == 1, "InsertLeave autocmd should exist")
```

---

### Test 1.3: エスケープシーケンスによるNormalモード移行

**手順**:

1. 空のバッファでInsertモード開始
2. 全角で`ｋ`を入力
3. 200ms以内に全角で`ｊ`を入力
4. モードとバッファ内容を確認

**期待される結果**:

- Normalモードに移行する
- バッファから`ｋｊ`が削除される
- IMEがOFFになる
- カーソル位置が入力前の位置に戻る

**検証ポイント**:

```lua
-- InsertCharPreイベントが登録されているか
local escape_autocmds = vim.api.nvim_get_autocmds({
  group = "ime_auto_escape"
})
assert(#escape_autocmds > 0, "escape sequence autocmd should be registered")

-- エスケープシーケンスが正しく検出されるか
local escape = require("ime-auto.escape")
assert(escape.on_insert_char_pre ~= nil, "on_insert_char_pre should exist")
```

---

### Test 1.4: エスケープシーケンスの文字削除精度

**手順**:

1. Insertモードで`あいう`と入力
2. `ｋｊ`と入力
3. バッファ内容を確認

**期待される結果**:

- バッファには`あいう`のみが残る
- `ｋｊ`は削除される
- カーソルは`う`の直後

**検証ポイント**:

```lua
-- 文字列置換が正確に行われるか
local line_content = vim.api.nvim_get_current_line()
local cursor_pos = vim.api.nvim_win_get_cursor(0)

assert(line_content == "あいう", "Escape sequence should be deleted")
assert(cursor_pos[2] == vim.fn.strlen("あいう"), "Cursor should be at correct position")
```

## 実装例

```lua
-- tests/priority-1/basic_ime_switching_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local escape = require("ime-auto.escape")

describe("Test 01: Basic IME switching", function()
  before_each(function()
    -- テスト用の設定
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    -- クリーンな状態を確保
    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    -- クリーンアップ
    vim.cmd("bdelete!")
  end)

  describe("1.1: InsertEnter時のIME復元", function()
    it("should register InsertEnter autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      local insert_enter = vim.tbl_filter(function(cmd)
        return cmd.event == "InsertEnter"
      end, autocmds)

      assert.equals(1, #insert_enter)
    end)

    it("should restore IME state on InsertEnter", function()
      -- 初回Insert: IME状態を保存
      vim.cmd("startinsert")
      local initial_state = ime.get_status()
      vim.cmd("stopinsert")
      vim.wait(50) -- オートコマンド実行待機

      -- 2回目Insert: 状態復元確認
      vim.cmd("startinsert")
      vim.wait(50)
      local restored_state = ime.get_status()

      assert.equals(initial_state, restored_state)

      vim.cmd("stopinsert")
    end)
  end)

  describe("1.2: InsertLeave時のIME OFF", function()
    it("should register InsertLeave autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      local insert_leave = vim.tbl_filter(function(cmd)
        return cmd.event == "InsertLeave"
      end, autocmds)

      assert.equals(1, #insert_leave)
    end)

    it("should turn off IME on InsertLeave", function()
      vim.cmd("startinsert")
      vim.wait(50)

      -- InsertLeave発火
      vim.cmd("stopinsert")
      vim.wait(50) -- デバウンス待機

      -- macOS以外ではIMEがOFFになるはず
      -- macOSはトグルベースなので、状態が保存されていればOK
      local config = require("ime-auto.config").get()
      if config.os ~= "macos" then
        local ime_status = ime.get_status()
        assert.is_false(ime_status)
      end
    end)
  end)

  describe("1.3: エスケープシーケンスによるNormalモード移行", function()
    it("should register InsertCharPre autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({
        group = "ime_auto_escape"
      })

      assert.is_true(#autocmds > 0)
    end)

    it("should transition to Normal mode on escape sequence", function()
      vim.cmd("startinsert")
      assert.equals("i", vim.api.nvim_get_mode().mode)

      -- エスケープシーケンス入力シミュレーション
      -- 注: 実際のキー入力シミュレーションはfeedkeys()を使用
      vim.fn.feedkeys("ｋｊ", "nx")
      vim.wait(300) -- escape_timeout + バッファ

      -- Normalモードに戻っているか
      assert.equals("n", vim.api.nvim_get_mode().mode)
    end)
  end)

  describe("1.4: エスケープシーケンスの文字削除精度", function()
    it("should delete escape sequence from buffer", function()
      vim.cmd("startinsert")

      -- 日本語入力 + エスケープシーケンス
      vim.fn.feedkeys("あいうｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      assert.equals("あいう", line)
    end)

    it("should position cursor correctly after deletion", function()
      vim.cmd("startinsert")

      vim.fn.feedkeys("testｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      local cursor = vim.api.nvim_win_get_cursor(0)

      assert.equals("test", line)
      assert.equals(vim.fn.strlen("test"), cursor[2])
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **プラグインが正しくロードされているか**
   ```lua
   assert.is_true(vim.g.loaded_ime_auto == true)
   ```

2. **OS検出が正しいか**
   ```lua
   local config = require("ime-auto.config").get()
   print("Detected OS:", config.os)
   ```

3. **デバッグモードで詳細ログ確認**
   ```lua
   require("ime-auto").setup({ debug = true })
   ```

4. **macOSでSwiftツールがコンパイルされているか**
   ```bash
   ls -la ~/.local/share/nvim/ime-auto/swift-ime
   ```

### 既知の問題

- **macOS**: 初回起動時にSwiftツールのコンパイルに数秒かかる
- **Windows**: PowerShellの実行ポリシーによってはエラーになる可能性
- **Linux**: fcitx/ibusがインストールされていない場合は動作しない

## 成功基準

以下のすべての条件を満たすこと：

- ✅ InsertEnter/InsertLeaveのオートコマンドが登録されている
- ✅ InsertモードでIME状態が復元される
- ✅ NormalモードでIMEがOFFになる
- ✅ エスケープシーケンスでNormalモードに移行する
- ✅ エスケープシーケンスがバッファから削除される
- ✅ カーソル位置が正しい

## 関連テストケース

- [02: 高速モード切り替えでの競合状態](./02-rapid-mode-switching.md)
- [03: マルチバイト文字境界の正確性](./03-multibyte-char-boundaries.md)
- [05: IME状態の保存と復元](./05-ime-state-persistence.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
