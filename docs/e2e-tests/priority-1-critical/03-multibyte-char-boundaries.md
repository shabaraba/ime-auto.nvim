# テストケース 03: マルチバイト文字境界の正確性

**優先度**: Priority 1 - Critical
**カテゴリ**: 文字エンコーディング・バッファ操作
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、エスケープシーケンス処理時のマルチバイト文字（全角文字、絵文字、4バイトUTF-8文字）境界の正確な処理を検証します。

### テストの重要性

- ✅ **潜在的バグ**: コードレビューで特定された文字境界問題（信頼度90%）
- ✅ **日本語入力の本質**: 全角文字処理はこのプラグインの核心機能
- ✅ **データ破損リスク**: 境界計算ミスは文字化けやカーソル位置ずれを引き起こす

### 発見された問題

**ファイル**: `/lua/ime-auto/escape.lua` (L20-44)

**問題点**:
```lua
local col = vim.api.nvim_win_get_cursor(0)[2]  -- バイト単位
local seq_len = vim.fn.strchars(escape_seq)    -- 文字単位

if col >= seq_len then  -- 単位の不一致!
  local before_cursor = vim.fn.strpart(line, 0, col)  -- バイト単位
  local last_chars = vim.fn.strcharpart(before_cursor,
    vim.fn.strchars(before_cursor) - seq_len)  -- 文字単位
```

`col`（バイトオフセット）と`seq_len`（文字数）を直接比較しており、マルチバイト文字の存在下で正しく動作しない可能性があります。

## 関連ファイル

- `/lua/ime-auto/escape.lua` (L14-77: エスケープシーケンス処理)
- 特にL20-44の`handle_escape_sequence()`関数

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- UTF-8エンコーディング有効
-- テストフレームワーク: plenary.nvim
```

### 初期設定

```lua
require("ime-auto").setup({
  escape_sequence = "ｋｊ",  -- 全角2文字
  escape_timeout = 200,
  debug = true,
})

-- UTF-8エンコーディング確認
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
```

## テストステップ

### Test 3.1: 全角日本語後のエスケープシーケンス

**手順**:

1. 空のバッファでInsertモード開始
2. 全角ひらがな入力: `あいう`
3. エスケープシーケンス入力: `ｋｊ`
4. バッファ内容とカーソル位置を確認

**期待される結果**:

- バッファ: `あいう`（`ｋｊ`は削除されている）
- カーソル位置: `あいう`の直後（バイトオフセット=9）
- モード: Normal

**検証ポイント**:

```lua
local line = vim.api.nvim_get_current_line()
assert.equals("あいう", line)

local cursor = vim.api.nvim_win_get_cursor(0)
-- ひらがな3文字 = 9バイト（UTF-8で各3バイト）
assert.equals(9, cursor[2])

assert.equals("n", vim.api.nvim_get_mode().mode)
```

---

### Test 3.2: 絵文字後のエスケープシーケンス

**手順**:

1. Insertモード開始
2. 絵文字入力: `😀🎉`（4バイトUTF-8文字）
3. エスケープシーケンス入力: `ｋｊ`
4. バッファとカーソル確認

**期待される結果**:

- バッファ: `😀🎉`
- カーソル位置: 絵文字2文字の直後（バイトオフセット=8）
- 文字化けなし

**検証ポイント**:

```lua
local line = vim.api.nvim_get_current_line()
assert.equals("😀🎉", line)

-- 絵文字は各4バイト
local cursor = vim.api.nvim_win_get_cursor(0)
assert.equals(8, cursor[2])
```

---

### Test 3.3: 混在文字列でのエスケープシーケンス

**手順**:

1. Insertモード開始
2. 複合入力: `ABC あいう 😀 testｋｊ`
3. バッファとカーソル確認

**期待される結果**:

- バッファ: `ABC あいう 😀 test`
- 各文字の境界が正しく保たれる
- カーソルが正確な位置

**検証ポイント**:

```lua
local line = vim.api.nvim_get_current_line()
assert.equals("ABC あいう 😀 test", line)

-- バイト数計算:
-- ABC = 3, スペース = 1, あいう = 9, スペース = 1, 😀 = 4, スペース = 1, test = 4
-- 合計 = 23バイト
local cursor = vim.api.nvim_win_get_cursor(0)
assert.equals(23, cursor[2])
```

---

### Test 3.4: 行頭でのエスケープシーケンス

**手順**:

1. Insertモード開始
2. 行頭で即座にエスケープシーケンス入力: `ｋｊ`
3. バッファとカーソル確認

**期待される結果**:

- バッファ: 空行
- カーソル: 行頭（オフセット=0）
- エラーなし

**検証ポイント**:

```lua
local line = vim.api.nvim_get_current_line()
assert.equals("", line)

local cursor = vim.api.nvim_win_get_cursor(0)
assert.equals(0, cursor[2])
```

---

### Test 3.5: エスケープシーケンス直前の文字境界

**手順**:

1. Insertモード開始
2. 複雑な境界パターン入力:
   - ケースA: `𠮷ｋｊ`（4バイト漢字 + エスケープ）
   - ケースB: `👨‍👩‍👧‍👦ｋｊ`（ZWJ結合絵文字 + エスケープ）
   - ケースC: `カｋｊ`（全角カタカナ + エスケープ）
3. 各ケースでバッファ検証

**期待される結果**:

- ケースA: `𠮷`のみ残る
- ケースB: `👨‍👩‍👧‍👦`のみ残る
- ケースC: `カ`のみ残る

**検証ポイント**:

```lua
-- ケースA: 4バイトUTF-8文字
vim.cmd("enew!")
vim.cmd("startinsert")
vim.fn.feedkeys("𠮷ｋｊ", "nx")
vim.wait(300)
assert.equals("𠮷", vim.api.nvim_get_current_line())

-- ケースB: ZWJ結合絵文字
vim.cmd("enew!")
vim.cmd("startinsert")
vim.fn.feedkeys("👨‍👩‍👧‍👦ｋｊ", "nx")
vim.wait(300)
assert.equals("👨‍👩‍👧‍👦", vim.api.nvim_get_current_line())

-- ケースC: 全角カタカナ
vim.cmd("enew!")
vim.cmd("startinsert")
vim.fn.feedkeys("カｋｊ", "nx")
vim.wait(300)
assert.equals("カ", vim.api.nvim_get_current_line())
```

---

### Test 3.6: エスケープシーケンスが部分一致する場合

**手順**:

1. Insertモード開始
2. エスケープシーケンスの一部を含む入力: `ｋあｊ`
3. Normalモード移行を確認（移行しないはず）

**期待される結果**:

- バッファ: `ｋあｊ`
- モード: Insert（エスケープシーケンスとして認識されない）

**検証ポイント**:

```lua
vim.cmd("startinsert")
vim.fn.feedkeys("ｋ", "nx")
vim.wait(100)
vim.fn.feedkeys("あ", "nx")
vim.wait(100)

-- pending_charがクリアされている
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.fn.feedkeys("ｊ", "nx")
vim.wait(100)

-- まだInsertモード
assert.equals("i", vim.api.nvim_get_mode().mode)

vim.cmd("stopinsert")
local line = vim.api.nvim_get_current_line()
assert.equals("ｋあｊ", line)
```

---

### Test 3.7: strpart vs strcharpartの正確性検証

**手順**:

1. Luaスクリプトで直接テスト
2. 様々な文字列に対して境界計算を検証

**期待される結果**:

- バイト単位と文字単位の計算が正しく分離される
- 境界エラーが発生しない

**検証ポイント**:

```lua
-- テスト文字列
local test_strings = {
  { str = "あいう", bytes = 9, chars = 3 },
  { str = "😀🎉", bytes = 8, chars = 2 },
  { str = "ABC", bytes = 3, chars = 3 },
  { str = "𠮷野家", bytes = 10, chars = 3 },
}

for _, test in ipairs(test_strings) do
  local byte_len = vim.fn.strlen(test.str)
  local char_len = vim.fn.strchars(test.str)

  assert.equals(test.bytes, byte_len,
    string.format("Byte length mismatch for '%s'", test.str))
  assert.equals(test.chars, char_len,
    string.format("Char length mismatch for '%s'", test.str))
end
```

## 実装例

```lua
-- tests/priority-1/multibyte_char_boundaries_spec.lua
local ime_auto = require("ime-auto")

describe("Test 03: Multibyte character boundaries", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
    vim.opt.encoding = "utf-8"
    vim.opt.fileencoding = "utf-8"
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("3.1: 全角日本語後のエスケープシーケンス", function()
    it("should correctly delete escape sequence after hiragana", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("あいうｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      assert.equals("あいう", line)

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(9, cursor[2]) -- 3文字 × 3バイト

      assert.equals("n", vim.api.nvim_get_mode().mode)
    end)
  end)

  describe("3.2: 絵文字後のエスケープシーケンス", function()
    it("should handle 4-byte UTF-8 emoji correctly", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("😀🎉ｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      assert.equals("😀🎉", line)

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(8, cursor[2]) -- 2絵文字 × 4バイト
    end)
  end)

  describe("3.3: 混在文字列でのエスケープシーケンス", function()
    it("should preserve character boundaries in mixed content", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("ABC あいう 😀 testｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      assert.equals("ABC あいう 😀 test", line)

      -- バイト数: 3 + 1 + 9 + 1 + 4 + 1 + 4 = 23
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(23, cursor[2])
    end)
  end)

  describe("3.4: 行頭でのエスケープシーケンス", function()
    it("should handle escape sequence at line start", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("ｋｊ", "nx")
      vim.wait(300)

      local line = vim.api.nvim_get_current_line()
      assert.equals("", line)

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(0, cursor[2])

      assert.equals("n", vim.api.nvim_get_mode().mode)
    end)
  end)

  describe("3.5: エスケープシーケンス直前の文字境界", function()
    it("should handle 4-byte kanji before escape sequence", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("𠮷ｋｊ", "nx")
      vim.wait(300)

      assert.equals("𠮷", vim.api.nvim_get_current_line())
    end)

    it("should handle ZWJ emoji sequence", function()
      vim.cmd("startinsert")
      -- 家族絵文字（ZWJ結合）
      vim.fn.feedkeys("👨‍👩‍👧‍👦ｋｊ", "nx")
      vim.wait(300)

      assert.equals("👨‍👩‍👧‍👦", vim.api.nvim_get_current_line())
    end)

    it("should handle full-width katakana", function()
      vim.cmd("startinsert")
      vim.fn.feedkeys("カｋｊ", "nx")
      vim.wait(300)

      assert.equals("カ", vim.api.nvim_get_current_line())
    end)
  end)

  describe("3.6: エスケープシーケンスが部分一致する場合", function()
    it("should not trigger on partial match", function()
      vim.cmd("startinsert")

      vim.fn.feedkeys("ｋ", "nx")
      vim.wait(100)

      vim.fn.feedkeys("あ", "nx") -- pending_charをクリア
      vim.wait(100)

      assert.equals("i", vim.api.nvim_get_mode().mode)

      vim.fn.feedkeys("ｊ", "nx")
      vim.wait(100)

      assert.equals("i", vim.api.nvim_get_mode().mode)

      vim.cmd("stopinsert")
      assert.equals("ｋあｊ", vim.api.nvim_get_current_line())
    end)
  end)

  describe("3.7: strpart vs strcharpartの正確性検証", function()
    it("should correctly calculate byte and character lengths", function()
      local test_cases = {
        { str = "あいう", bytes = 9, chars = 3 },
        { str = "😀🎉", bytes = 8, chars = 2 },
        { str = "ABC", bytes = 3, chars = 3 },
        { str = "𠮷野家", bytes = 10, chars = 3 },
      }

      for _, test in ipairs(test_cases) do
        local byte_len = vim.fn.strlen(test.str)
        local char_len = vim.fn.strchars(test.str)

        assert.equals(test.bytes, byte_len,
          string.format("Byte length for '%s'", test.str))
        assert.equals(test.chars, char_len,
          string.format("Char length for '%s'", test.str))
      end
    end)

    it("should correctly extract substrings", function()
      local str = "あいう😀test"

      -- strpart: バイト単位
      local byte_part = vim.fn.strpart(str, 0, 9) -- "あいう"
      assert.equals("あいう", byte_part)

      -- strcharpart: 文字単位
      local char_part = vim.fn.strcharpart(str, 0, 3) -- "あいう"
      assert.equals("あいう", char_part)
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **エンコーディング設定**
   ```lua
   print(vim.opt.encoding:get())  -- "utf-8"であるべき
   print(vim.opt.fileencoding:get())
   ```

2. **端末のUTF-8サポート**
   ```bash
   echo $LANG  # UTF-8を含むべき
   locale  # LC_ALL, LC_CTYPEを確認
   ```

3. **feedkeys()の動作**
   ```lua
   -- "nx"フラグ: キューに追加、特殊キー解釈なし
   vim.fn.feedkeys("テスト", "nx")
   ```

4. **デバッグ: 実際のバイト数確認**
   ```lua
   local str = "あいう"
   print("Bytes:", vim.fn.strlen(str))
   print("Chars:", vim.fn.strchars(str))
   print("Byte dump:", vim.fn.split(str, "\\zs"))
   ```

### 既知の問題

- **端末エミュレータ依存**: 一部の絵文字が正しく表示されない場合がある
- **フォント依存**: ZWJ結合絵文字の表示がフォントに依存
- **Neovimバージョン**: v0.9.0以前はUTF-8サポートに問題がある可能性

## 成功基準

以下のすべての条件を満たすこと：

- ✅ 全角ひらがな、カタカナ、漢字後のエスケープシーケンスが正しく動作
- ✅ 絵文字（4バイトUTF-8）後のエスケープシーケンスが正しく動作
- ✅ 混在文字列での境界が正確に保たれる
- ✅ 行頭でのエスケープシーケンスが正しく動作
- ✅ ZWJ結合絵文字など複雑なUnicodeシーケンスが破損しない
- ✅ カーソル位置が常に正確（バイトオフセット）

## 関連テストケース

- [01: 基本的なIME切り替え](./01-basic-ime-switching.md)
- [04: Swiftツールのコンパイルとリカバリ](./04-swift-tool-compilation.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
