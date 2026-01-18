# テストケース 05: IME状態の保存と復元

**優先度**: Priority 1 - Critical
**カテゴリ**: 状態管理・ユーザー体験
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、InsertモードとNormalモード間でのIME状態の保存と復元が正確に動作することを検証します。これはユーザー体験の核心となる機能です。

### テストの重要性

- ✅ **ユーザー体験の本質**: 「前回の状態を覚えている」がこのプラグインの価値
- ✅ **ワークフロー効率**: 毎回IMEをON/OFFする手間を省く
- ✅ **OS間の一貫性**: macOS（トグルベース）と他OS（状態ベース）の違いを吸収

### テストする機能

1. **InsertモードでのIME状態保存**
2. **Normalモード復帰時の状態記録**
3. **再度InsertモードでIME状態復元**
4. **複数回のモード切り替えでの状態追跡**

## 関連ファイル

- `/lua/ime-auto/ime.lua` (L195-216: save_state/restore_state)
- `/lua/ime-auto/init.lua` (L11-33: オートコマンド)
- `/swift/ime-tool.swift` (L105-156: macOS slotベース管理)

## 前提条件

### 環境

```lua
-- Neovim: v0.9.0以降
-- ime-auto.nvim: インストール済み
-- IME: システムに日本語IMEがインストール済み
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

### Test 5.1: InsertモードでのIME=ON状態の保存と復元

**手順**:

1. Normalモードで開始
2. Insertモード開始（IME=OFFと想定）
3. 手動でIME=ONに切り替え
4. Normalモードに戻る（`<Esc>`またはエスケープシーケンス）
5. 再度Insertモード開始
6. IME状態を確認（ONに復元されるはず）

**期待される結果**:

- Step 4でIME状態が保存される
- Step 6でIME=ONに自動復元される
- ユーザーは手動切り替え不要

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")

-- 初回Insert（IME=OFF想定）
vim.cmd("startinsert")
vim.wait(50)

-- IMEをONに（実際のキー操作）
-- macOS: Ctrl+Space または Cmd+Space
-- Windows/Linux: IME制御を直接呼び出し
ime.on()
vim.wait(50)

local ime_on_state = ime.get_status()
assert.is_true(ime_on_state) -- 非macOSの場合

-- Normalモードへ（状態保存）
vim.cmd("stopinsert")
vim.wait(100) -- デバウンス待機

-- 再度Insert（状態復元）
vim.cmd("startinsert")
vim.wait(50)

local restored_state = ime.get_status()

-- macOSはトグルベースなので常にON、他OSは前回状態
local config = require("ime-auto.config").get()
if config.os ~= "macos" then
  assert.equals(ime_on_state, restored_state)
end
```

---

### Test 5.2: InsertモードでのIME=OFF状態の保存と復元

**手順**:

1. Insertモード開始
2. IME=OFFのまま維持（デフォルト）
3. Normalモードに戻る
4. 再度Insertモード開始
5. IME状態を確認（OFFのまま）

**期待される結果**:

- Step 4でIME=OFF状態が保存される
- Step 5でIME=OFFのまま復元される

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")

-- Insert開始（IME=OFFのまま）
vim.cmd("startinsert")
vim.wait(50)

ime.off() -- 明示的にOFF
vim.wait(50)

local ime_off_state = ime.get_status()
assert.is_false(ime_off_state) -- 非macOSの場合

-- Normal → Insert
vim.cmd("stopinsert")
vim.wait(100)

vim.cmd("startinsert")
vim.wait(50)

local restored_state = ime.get_status()

local config = require("ime-auto.config").get()
if config.os ~= "macos" then
  assert.is_false(restored_state)
end
```

---

### Test 5.3: 複数回のモード切り替えでの状態追跡

**手順**:

1. Insert (IME=ON) → Normal → Insert (ON復元)
2. Insert (IME=OFF切替) → Normal → Insert (OFF復元)
3. 上記を3回繰り返す

**期待される結果**:

- 各Insertモードで正しい状態が復元される
- 状態が混ざらない（ON/OFFの履歴が正確）

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")
local config = require("ime-auto.config").get()

if config.os == "macos" then
  pending("macOSはトグルベースのため、このテストはスキップ")
  return
end

for cycle = 1, 3 do
  -- IME=ON セッション
  vim.cmd("startinsert")
  ime.on()
  vim.wait(50)
  assert.is_true(ime.get_status())

  vim.cmd("stopinsert")
  vim.wait(100)

  vim.cmd("startinsert")
  vim.wait(50)
  assert.is_true(ime.get_status(), "Cycle " .. cycle .. ": ON should be restored")

  vim.cmd("stopinsert")
  vim.wait(100)

  -- IME=OFF セッション
  vim.cmd("startinsert")
  ime.off()
  vim.wait(50)
  assert.is_false(ime.get_status())

  vim.cmd("stopinsert")
  vim.wait(100)

  vim.cmd("startinsert")
  vim.wait(50)
  assert.is_false(ime.get_status(), "Cycle " .. cycle .. ": OFF should be restored")

  vim.cmd("stopinsert")
  vim.wait(100)
end
```

---

### Test 5.4: macOSのslotベース管理の検証

**手順** (macOS専用):

1. Insertモード開始（slot Aに現在IME保存）
2. Normalモードへ（slot Bに現在IME保存）
3. 再度Insertモード（slot Aから復元）
4. slot Aとslot Bの内容を確認

**期待される結果**:

- slot A: Insertモード用IME ID
- slot B: Normalモード用IME ID（通常は英語）
- トグル動作が正確

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local config = require("ime-auto.config").get()

if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

-- slot A/Bのパス
local data_dir = vim.fn.stdpath('data')
local slot_a_path = data_dir .. '/ime-auto/saved-ime-a.txt'
local slot_b_path = data_dir .. '/ime-auto/saved-ime-b.txt'

-- 初期状態取得
local initial_ime = swift_tool.get_current()

-- Insert開始 → slot Aに保存
vim.cmd("startinsert")
vim.wait(100)

-- slot Aの内容確認
local slot_a_content = vim.fn.readfile(slot_a_path)
assert.is_true(#slot_a_content > 0)

-- Normal → slot Bに保存
vim.cmd("stopinsert")
vim.wait(100)

local slot_b_content = vim.fn.readfile(slot_b_path)
assert.is_true(#slot_b_content > 0)

-- slot AとBが異なることを確認（異なるIME）
assert.is_not_equal(slot_a_content[1], slot_b_content[1])

-- 再度Insert → slot Aから復元
vim.cmd("startinsert")
vim.wait(100)

local restored_ime = swift_tool.get_current()
assert.equals(slot_a_content[1], restored_ime)

vim.cmd("stopinsert")
```

---

### Test 5.5: 初回起動時のlast_ime_stateがnilの場合

**手順**:

1. プラグイン初回起動（last_ime_state = nil）
2. Insertモード開始
3. restore_state()が現在のIME状態を取得することを確認
4. 状態が保存されることを確認

**期待される結果**:

- last_ime_state = nilでもエラーなし
- restore_state()が現在の状態を取得
- 以降は正常に状態管理される

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")

-- ime.luaの内部変数 last_ime_state をnilに設定
-- (実装上は外部からアクセスできないため、初回起動をシミュレート)

-- restore_state()を直接呼び出し
ime.restore_state()

-- エラーなく完了
-- 内部的に last_ime_state = ime.get_status() が実行される

-- 以降の状態管理が正常
vim.cmd("startinsert")
vim.wait(50)

local state1 = ime.get_status()

vim.cmd("stopinsert")
vim.wait(100)

vim.cmd("startinsert")
vim.wait(50)

local state2 = ime.get_status()

-- 状態が保持されている
local config = require("ime-auto.config").get()
if config.os ~= "macos" then
  assert.equals(state1, state2)
end
```

---

### Test 5.6: 異なるバッファ間での状態独立性

**手順**:

1. バッファ1でInsert (IME=ON)
2. バッファ2に切り替え
3. バッファ2でInsert (IME=ON想定)
4. バッファ1に戻ってInsert
5. IME状態が維持されているか確認

**期待される結果**:

- 各バッファで独立した状態管理（理想）
- または、グローバルなIME状態が一貫している

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")

-- バッファ1
vim.cmd("enew")
local buf1 = vim.api.nvim_get_current_buf()

vim.cmd("startinsert")
ime.on()
vim.wait(50)

local buf1_state = ime.get_status()
vim.cmd("stopinsert")
vim.wait(100)

-- バッファ2
vim.cmd("enew")
local buf2 = vim.api.nvim_get_current_buf()

vim.cmd("startinsert")
vim.wait(50)

local buf2_state = ime.get_status()

-- バッファ1に戻る
vim.api.nvim_set_current_buf(buf1)
vim.cmd("startinsert")
vim.wait(50)

local buf1_restored = ime.get_status()

-- 状態が保持されている
local config = require("ime-auto.config").get()
if config.os ~= "macos" then
  assert.equals(buf1_state, buf1_restored)
end

vim.cmd("stopinsert")
```

---

### Test 5.7: プラグイン無効化後の再有効化での状態

**手順**:

1. Insert (IME=ON) → Normal
2. `:ImeAutoDisable` でプラグイン無効化
3. Insert → Normal（IME制御なし）
4. `:ImeAutoEnable` で再有効化
5. Insert時の状態確認

**期待される結果**:

- 無効化前の状態は保持されない
- 再有効化後は新たに状態管理を開始

**検証ポイント**:

```lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

-- 状態保存
vim.cmd("startinsert")
ime.on()
vim.wait(50)

vim.cmd("stopinsert")
vim.wait(100)

-- 無効化
ime_auto.disable()

-- Insert → Normal (IME制御されない)
vim.cmd("startinsert")
vim.wait(50)
vim.cmd("stopinsert")
vim.wait(100)

-- 再有効化
ime_auto.enable()

-- Insert時の動作確認
vim.cmd("startinsert")
vim.wait(50)

-- 無効化前の状態は関係なく、現在の状態から開始
local current_state = ime.get_status()
assert.is_not_nil(current_state)

vim.cmd("stopinsert")
```

## 実装例

```lua
-- tests/priority-1/ime_state_persistence_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 05: IME state persistence", function()
  local config = nil

  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    config = require("ime-auto.config").get()

    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("5.1: IME=ON状態の保存と復元", function()
    it("should save and restore IME ON state", function()
      if config.os == "macos" then
        pending("macOS uses toggle-based system")
        return
      end

      vim.cmd("startinsert")
      ime.on()
      vim.wait(50)

      assert.is_true(ime.get_status())

      vim.cmd("stopinsert")
      vim.wait(100)

      vim.cmd("startinsert")
      vim.wait(50)

      assert.is_true(ime.get_status())

      vim.cmd("stopinsert")
    end)
  end)

  describe("5.2: IME=OFF状態の保存と復元", function()
    it("should save and restore IME OFF state", function()
      if config.os == "macos" then
        pending("macOS uses toggle-based system")
        return
      end

      vim.cmd("startinsert")
      ime.off()
      vim.wait(50)

      assert.is_false(ime.get_status())

      vim.cmd("stopinsert")
      vim.wait(100)

      vim.cmd("startinsert")
      vim.wait(50)

      assert.is_false(ime.get_status())

      vim.cmd("stopinsert")
    end)
  end)

  describe("5.3: 複数回のモード切り替え", function()
    it("should track state across multiple mode switches", function()
      if config.os == "macos" then
        pending("macOS uses toggle-based system")
        return
      end

      for cycle = 1, 3 do
        -- ON cycle
        vim.cmd("startinsert")
        ime.on()
        vim.wait(50)
        assert.is_true(ime.get_status())

        vim.cmd("stopinsert")
        vim.wait(100)

        vim.cmd("startinsert")
        vim.wait(50)
        assert.is_true(ime.get_status(), "Cycle " .. cycle .. " ON")

        vim.cmd("stopinsert")
        vim.wait(100)

        -- OFF cycle
        vim.cmd("startinsert")
        ime.off()
        vim.wait(50)
        assert.is_false(ime.get_status())

        vim.cmd("stopinsert")
        vim.wait(100)

        vim.cmd("startinsert")
        vim.wait(50)
        assert.is_false(ime.get_status(), "Cycle " .. cycle .. " OFF")

        vim.cmd("stopinsert")
        vim.wait(100)
      end
    end)
  end)

  describe("5.4: macOSのslotベース管理", function()
    it("should manage slot A and B correctly", function()
      if config.os ~= "macos" then
        pending("This test is macOS only")
        return
      end

      local swift_tool = require("ime-auto.swift-ime-tool")
      local data_dir = vim.fn.stdpath('data')
      local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'
      local slot_b = data_dir .. '/ime-auto/saved-ime-b.txt'

      -- Insert → slot A保存
      vim.cmd("startinsert")
      vim.wait(100)

      assert.equals(1, vim.fn.filereadable(slot_a))

      -- Normal → slot B保存
      vim.cmd("stopinsert")
      vim.wait(100)

      assert.equals(1, vim.fn.filereadable(slot_b))

      -- slot内容が異なる
      local slot_a_ime = vim.fn.readfile(slot_a)[1]
      local slot_b_ime = vim.fn.readfile(slot_b)[1]

      assert.is_not_equal(slot_a_ime, slot_b_ime)
    end)
  end)

  describe("5.6: 異なるバッファ間での状態", function()
    it("should maintain state across buffer switches", function()
      if config.os == "macos" then
        pending("macOS uses toggle-based system")
        return
      end

      -- Buffer 1
      vim.cmd("enew")
      local buf1 = vim.api.nvim_get_current_buf()

      vim.cmd("startinsert")
      ime.on()
      vim.wait(50)

      local buf1_state = ime.get_status()
      vim.cmd("stopinsert")
      vim.wait(100)

      -- Buffer 2
      vim.cmd("enew")

      -- Buffer 1に戻る
      vim.api.nvim_set_current_buf(buf1)
      vim.cmd("startinsert")
      vim.wait(50)

      local restored = ime.get_status()
      assert.equals(buf1_state, restored)

      vim.cmd("stopinsert")
    end)
  end)

  describe("5.7: プラグイン再有効化", function()
    it("should reset state on re-enable", function()
      vim.cmd("startinsert")
      ime.on()
      vim.wait(50)

      vim.cmd("stopinsert")
      vim.wait(100)

      ime_auto.disable()

      vim.cmd("startinsert")
      vim.cmd("stopinsert")

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

1. **last_ime_stateの初期化**
   ```lua
   -- ime.lua:207-209
   if last_ime_state == nil then
     last_ime_state = M.get_status()
   end
   ```

2. **OS別の実装差異**
   - macOS: トグルベース（slot A/B）
   - Windows/Linux: 状態ベース（last_ime_state）

3. **デバウンス待機時間**
   - InsertLeave後、100ms待機してからInsertEnter

4. **デバッグログ確認**
   ```lua
   require("ime-auto").setup({ debug = true })
   ```

### 既知の問題

- **macOS**: slotシステムのため、ON/OFF状態の直接比較が困難
- **Windows**: トグル方式のため、状態検出に限界がある
- **タイミング依存**: vim.wait()の精度に依存

## 成功基準

以下のすべての条件を満たすこと：

- ✅ IME=ON状態がNormalモード経由で復元される
- ✅ IME=OFF状態がNormalモード経由で復元される
- ✅ 複数回のモード切り替えで状態が混ざらない
- ✅ macOSのslot A/Bが正しく動作する
- ✅ 初回起動時（last_ime_state=nil）でもエラーなし
- ✅ 異なるバッファ間で状態が維持される（またはグローバルに一貫）

## 関連テストケース

- [01: 基本的なIME切り替え](./01-basic-ime-switching.md)
- [02: 高速モード切り替えでの競合状態](./02-rapid-mode-switching.md)
- [04: Swiftツールのコンパイルとリカバリ](./04-swift-tool-compilation.md)
- [08: macOS slot初期化](../priority-2-important/08-macos-slot-initialization.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
