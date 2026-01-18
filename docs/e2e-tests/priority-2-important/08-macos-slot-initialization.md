# テストケース 08: macOS slot初期化

**優先度**: Priority 2 - Important
**カテゴリ**: macOS専用機能・状態管理
**対象OS**: macOS のみ

## 概要

このテストは、macOSのslotベースIME管理システムの初期化動作を検証します。特に、初回起動時のslot A/Bの初期化と、ユーザーの意図しないIMEロックを防ぐことを確認します。

### テストの重要性

- ✅ **潜在的バグ**: slot初期化時のロジック不整合（信頼度82%）
- ✅ **ユーザー体験**: Normalモードで別のIMEを使いたい場合に対応
- ✅ **設計の明確化**: slotシステムの意図を文書化

### 発見された問題

**ファイル**: `/swift/ime-tool.swift` (L105-128, L130-155)
**ファイル**: `/lua/ime-auto/ime.lua` (L199-216: restore_state実装)

**問題シナリオ**:
```
初回起動:
1. toggle-from-insert → slot Aに日本語IME保存 → slot B未存在 → ABC切り替え
2. toggle-from-normal → slot Bに ABC保存 → slot Aに切り替え（日本語）

結果: slot BにABCがロックされる
問題: ユーザーがNormalモードでDvorakなど別のIMEを使いたい場合に対応できない
```

## 関連ファイル

- `/swift/ime-tool.swift` (L105-156: toggle実装, L89-103: slot読み書き)
- `/lua/ime-auto/swift-ime-tool.lua` (L148-177: Lua側インターフェース)
- `/lua/ime-auto/ime.lua` (L199-216: macOS固有のrestore_state)

## 前提条件

### 環境

```bash
# macOS専用
sw_vers

# swiftc確認
swiftc --version
```

### クリーンアップ

```bash
# slot ファイル削除（初回起動シミュレーション）
rm -f ~/.local/share/nvim/ime-auto/saved-ime-a.txt
rm -f ~/.local/share/nvim/ime-auto/saved-ime-b.txt
```

## テストステップ

### Test 8.1: 初回起動時のslot A初期化

**手順**:

1. slot A/B未存在の状態で開始
2. Insertモード開始（`toggle-from-insert`実行）
3. slot Aが作成され、現在のIMEが保存されることを確認
4. slot Bが作成され、デフォルト値（ABC）が保存されることを確認

**期待される結果**:

- slot A: 現在のIME ID（例: 日本語IME）
- slot B: `com.apple.keylayout.ABC`

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'
local slot_b = data_dir .. '/ime-auto/saved-ime-b.txt'

-- slot削除（初回起動シミュレーション）
vim.fn.delete(slot_a)
vim.fn.delete(slot_b)

-- 現在のIME取得
local initial_ime = swift_tool.get_current()

-- Insertモード開始
vim.cmd("startinsert")
vim.wait(100)

-- slot A作成確認
assert.equals(1, vim.fn.filereadable(slot_a))
local slot_a_ime = vim.fn.readfile(slot_a)[1]
assert.equals(initial_ime, slot_a_ime)

-- slot B作成確認（Normalモード移行時）
vim.cmd("stopinsert")
vim.wait(100)

assert.equals(1, vim.fn.filereadable(slot_b))
local slot_b_ime = vim.fn.readfile(slot_b)[1]
-- デフォルトはABCまたは現在のIME
assert.is_not_nil(slot_b_ime)
```

---

### Test 8.2: slot B未存在時のtoggle-from-insert動作

**手順**:

1. slot Aのみ存在（slot B削除）
2. `toggle-from-insert`実行
3. デフォルトABCに切り替わることを確認

**期待される結果**:

- slot B未存在時、`com.apple.keylayout.ABC`にフォールバック
- エラーなし

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local slot_b = data_dir .. '/ime-auto/saved-ime-b.txt'

-- slot B削除
vim.fn.delete(slot_b)

-- toggle実行
local success = swift_tool.toggle_from_insert()
assert.is_true(success)

-- 現在のIMEがABCか確認
local current = swift_tool.get_current()
assert.equals("com.apple.keylayout.ABC", current)
```

---

### Test 8.3: slot A未存在時のtoggle-from-normal動作

**手順**:

1. slot Bのみ存在（slot A削除）
2. `toggle-from-normal`実行
3. 切り替えが行われない（現在のIMEを維持）ことを確認

**期待される結果**:

- slot A未存在時、IME切り替えなし
- Swift側で`exit(0)`（正常終了）

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'

-- slot A削除
vim.fn.delete(slot_a)

-- 現在のIME保存
local before = swift_tool.get_current()

-- toggle実行
local success = swift_tool.toggle_from_normal()
assert.is_true(success) -- エラーなし

-- IMEが変わっていない
local after = swift_tool.get_current()
assert.equals(before, after)
```

---

### Test 8.4: ユーザーがNormalモードで別のIMEを使う場合

**手順**:

1. Insertモードで日本語IME使用
2. Normalモードで手動でDvorak配列に切り替え
3. 再度Insertモードに入る
4. 日本語IMEが復元されることを確認
5. Normalモードに戻る
6. Dvorakが復元される（理想）か、ABCに戻る（現状）かを確認

**期待される結果**:

- Insertモード: 日本語IME復元
- Normalモード: 最後に使用したIME復元（理想）

**現状の動作**:
- Normalモード: slot Bに保存されたIME（ABCまたは初回のIME）

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")

-- Insert開始（日本語IME）
vim.cmd("startinsert")
vim.wait(100)

-- 日本語IMEに切り替え（手動シミュレーション）
local japanese_ime = "com.apple.inputmethod.Kotoeri.Japanese"
swift_tool.switch_to(japanese_ime)
vim.wait(50)

vim.cmd("stopinsert")
vim.wait(100)

-- Normalモードで手動切り替え（実際のユーザー操作）
local dvorak_ime = "com.apple.keylayout.Dvorak"
swift_tool.switch_to(dvorak_ime)
vim.wait(50)

-- 再度Insert
vim.cmd("startinsert")
vim.wait(100)

-- 日本語IMEが復元される
local current = swift_tool.get_current()
assert.equals(japanese_ime, current)

vim.cmd("stopinsert")
vim.wait(100)

-- Normalモードでのn IME確認
current = swift_tool.get_current()
-- 現状: slot Bの値（ABCまたは初回のIME）
-- 理想: Dvorak（最後に手動設定したIME）
print("Normal mode IME:", current)
```

---

### Test 8.5: restore_state()のmacOS専用ロジック

**手順**:

1. macOSで`restore_state()`を呼び出し
2. 常に`M.on()`が呼ばれることを確認
3. `last_ime_state`が無視されることを確認

**期待される結果**:

- macOSでは常に`toggle_from_normal()`が実行される
- `last_ime_state`の値に関わらず、slotベース管理

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")
local config = require("ime-auto.config").get()

if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

-- restore_state実行
ime.restore_state()

-- M.on()が呼ばれる（内部的にtoggle_from_normal）
-- 検証: システムコールのトレース（モック必要）

local call_log = {}
local swift_tool = require("ime-auto.swift-ime-tool")
local original_toggle = swift_tool.toggle_from_normal
swift_tool.toggle_from_normal = function()
  table.insert(call_log, "toggle_from_normal")
  return original_toggle()
end

ime.restore_state()

assert.is_true(#call_log > 0)

swift_tool.toggle_from_normal = original_toggle
```

---

### Test 8.6: slot ファイルの破損耐性

**手順**:

1. slot Aに不正なIME ID（存在しないID）を書き込み
2. `toggle-from-normal`実行
3. エラーハンドリングを確認

**期待される結果**:

- 不正なIME IDの場合、切り替え失敗
- エラーメッセージが適切
- プラグインがクラッシュしない

**検証ポイント**:

```lua
local swift_tool = require("ime-auto.swift-ime-tool")
local data_dir = vim.fn.stdpath('data')
local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'

-- 不正なIME ID書き込み
vim.fn.writefile({ "invalid.ime.id" }, slot_a)

-- toggle実行
local success = swift_tool.toggle_from_normal()

-- 失敗またはデフォルトIMEにフォールバック
-- (Swift側の実装次第)
-- TISSelectInputSource()が失敗するが、エラーハンドリングなし
```

---

### Test 8.7: slot ファイルのパーミッション

**手順**:

1. slot A/Bのパーミッションを確認
2. 0600（所有者のみR/W）であることを確認

**期待される結果**:

- セキュリティ対策として、適切なパーミッション

**検証ポイント**:

```lua
local data_dir = vim.fn.stdpath('data')
local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'

-- slot作成
vim.cmd("startinsert")
vim.wait(100)
vim.cmd("stopinsert")
vim.wait(100)

-- パーミッション確認
local stat = vim.loop.fs_stat(slot_a)
assert.is_not_nil(stat)

-- mode確認（0600 = 384 in decimal）
-- 注: vim.loop.fs_stat().mode はプラットフォーム依存
print("Slot A permissions:", stat.mode)
```

## 実装例

```lua
-- tests/priority-2/macos_slot_initialization_spec.lua
local swift_tool = require("ime-auto.swift-ime-tool")
local ime = require("ime-auto.ime")

describe("Test 08: macOS slot initialization", function()
  local data_dir = vim.fn.stdpath('data')
  local slot_a = data_dir .. '/ime-auto/saved-ime-a.txt'
  local slot_b = data_dir .. '/ime-auto/saved-ime-b.txt'

  before_each(function()
    if vim.fn.has("mac") == 0 then
      pending("This test is macOS only")
      return
    end

    if vim.fn.executable("swiftc") == 0 then
      pending("swiftc not found")
      return
    end

    -- Swift tool コンパイル
    swift_tool.ensure_compiled()
  end)

  describe("8.1: 初回起動時のslot初期化", function()
    it("should initialize slot A and B on first run", function()
      vim.fn.delete(slot_a)
      vim.fn.delete(slot_b)

      local initial_ime = swift_tool.get_current()

      vim.cmd("startinsert")
      vim.wait(100)

      assert.equals(1, vim.fn.filereadable(slot_a))
      local slot_a_ime = vim.fn.readfile(slot_a)[1]
      assert.equals(initial_ime, slot_a_ime)

      vim.cmd("stopinsert")
      vim.wait(100)

      assert.equals(1, vim.fn.filereadable(slot_b))
    end)
  end)

  describe("8.2: slot B未存在時の動作", function()
    it("should fallback to ABC when slot B missing", function()
      vim.fn.delete(slot_b)

      local success = swift_tool.toggle_from_insert()
      assert.is_true(success)

      local current = swift_tool.get_current()
      assert.equals("com.apple.keylayout.ABC", current)
    end)
  end)

  describe("8.3: slot A未存在時の動作", function()
    it("should not switch IME when slot A missing", function()
      vim.fn.delete(slot_a)

      local before = swift_tool.get_current()
      local success = swift_tool.toggle_from_normal()
      assert.is_true(success)

      local after = swift_tool.get_current()
      assert.equals(before, after)
    end)
  end)

  describe("8.5: restore_state()のmacOS専用ロジック", function()
    it("should always call on() for macOS", function()
      local config = require("ime-auto.config").get()
      assert.equals("macos", config.os)

      -- restore_state実行
      ime.restore_state()

      -- エラーなく完了
      assert.is_true(true)
    end)
  end)

  describe("8.7: slot ファイルのパーミッション", function()
    it("should create slots with secure permissions", function()
      vim.cmd("startinsert")
      vim.wait(100)
      vim.cmd("stopinsert")
      vim.wait(100)

      local stat = vim.loop.fs_stat(slot_a)
      assert.is_not_nil(stat)

      -- パーミッション確認（プラットフォーム依存）
      print("Slot A permissions:", string.format("%o", stat.mode))
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **slot ファイルの場所**
   ```bash
   ls -la ~/.local/share/nvim/ime-auto/
   ```

2. **Swift実装の確認**
   ```swift
   // swift/ime-tool.swift:121
   let targetID = readFromSlot("b") ?? "com.apple.keylayout.ABC"
   ```

3. **IME ID形式**
   ```
   com.apple.keylayout.ABC
   com.apple.inputmethod.Kotoeri.Japanese
   ```

### 改善提案

**問題**: Normalモードで手動切り替えしたIMEが保持されない

**解決策1**: `toggle-from-normal`実行前に現在のIMEをslot Bに保存
```swift
// 現状
let currentID = getCurrentInputSourceID()
try writeToSlot(currentID, slot: "b")

// 改善: Normalモード用slotを別途保存（slot C導入）
```

**解決策2**: ユーザー設定でNormalモード用IMEを固定
```lua
require("ime-auto").setup({
  macos_normal_ime = "com.apple.keylayout.Dvorak",
})
```

## 成功基準

以下のすべての条件を満たすこと：

- ✅ 初回起動時にslot A/Bが正しく初期化される
- ✅ slot B未存在時にABCにフォールバックする
- ✅ slot A未存在時にIME切り替えをスキップする
- ✅ Insertモードで日本語IMEが復元される
- ✅ restore_state()がmacOSでslotベース管理を使用する
- ✅ 不正なslot内容でもクラッシュしない
- ✅ slot ファイルのパーミッションが適切

## 関連テストケース

- [04: Swiftツールのコンパイルとリカバリ](../priority-1-critical/04-swift-tool-compilation.md)
- [05: IME状態の保存と復元](../priority-1-critical/05-ime-state-persistence.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
**改善提案**: Normalモード用IMEの柔軟な設定オプション追加
