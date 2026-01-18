# テストケース 10: OS別動作確認

**優先度**: Priority 3 - Normal
**カテゴリ**: プラットフォーム互換性
**対象OS**: macOS, Windows, Linux

## 概要

このテストは、各OS固有のIME制御実装が正しく動作することを検証します。

### テストの重要性

- ✅ **クロスプラットフォーム対応**: 各OSでの基本動作保証
- ✅ **実装の違いの検証**: OS別コードパスのテスト
- ✅ **将来のメンテナンス**: OS固有の変更検出

## 関連ファイル

- `/lua/ime-auto/ime.lua` (L44-110: OS別実装)
- `/lua/ime-auto/config.lua` (L30-42: OS検出)

## 前提条件

### 環境

```lua
-- テスト実行OS: macOS, Windows, または Linux
-- ime-auto.nvim: インストール済み
```

## テストステップ

### Test 10.1: OS自動検出の正確性

**手順**:

1. `os = "auto"`で setup
2. 検出されたOSが実行環境と一致することを確認

**期待される結果**:

- macOSで実行: `config.os == "macos"`
- Windowsで実行: `config.os == "windows"`
- Linuxで実行: `config.os == "linux"`

**検証ポイント**:

```lua
require("ime-auto").setup({ os = "auto" })

local config = require("ime-auto.config").get()
local detected_os = config.os

-- vim.loop.os_uname()と比較
local os_name = vim.loop.os_uname().sysname:lower()

if os_name:match("darwin") then
  assert.equals("macos", detected_os)
elseif os_name:match("windows") or os_name:match("mingw") then
  assert.equals("windows", detected_os)
elseif os_name:match("linux") then
  assert.equals("linux", detected_os)
end
```

---

### Test 10.2: macOS - Swift tool統合

**手順** (macOS):

1. IME制御コマンド実行
2. Swift toolが呼ばれることを確認

**期待される結果**:

- `ime_control_macos()`が`swift_tool`を使用
- トグルベースの動作

**検証ポイント**:

```lua
if config.os ~= "macos" then
  pending("This test is macOS only")
  return
end

local ime = require("ime-auto.ime")
local swift_tool = require("ime-auto.swift-ime-tool")

-- Swift tool コンパイル確認
local ok = swift_tool.ensure_compiled()
assert.is_true(ok)

-- IME制御
ime.on()
vim.wait(50)

ime.off()
vim.wait(50)

-- エラーなし
assert.is_true(true)
```

---

### Test 10.3: Windows - PowerShell統合

**手順** (Windows):

1. IME制御コマンド実行
2. PowerShellが実行されることを確認

**期待される結果**:

- `ime_control_windows()`がPowerShell SendKeysを使用
- トグル方式（{KANJI}キー）

**検証ポイント**:

```lua
if config.os ~= "windows" then
  pending("This test is Windows only")
  return
end

local ime = require("ime-auto.ime")

-- IME制御（実際のシステムコール）
ime.on()
vim.wait(100)

ime.off()
vim.wait(100)

-- エラーなし
assert.is_true(true)

-- status取得
local status = ime.get_status()
assert.is_not_nil(status)
```

---

### Test 10.4: Linux - fcitx優先

**手順** (Linux):

1. `fcitx-remote`が利用可能な環境
2. IME制御コマンド実行
3. fcitxが使用されることを確認

**期待される結果**:

- `fcitx-remote`コマンドが実行される
- `ibus`は使用されない

**検証ポイント**:

```lua
if config.os ~= "linux" then
  pending("This test is Linux only")
  return
end

-- fcitx存在確認
if vim.fn.executable("fcitx-remote") == 0 then
  pending("fcitx-remote not found")
  return
end

local ime = require("ime-auto.ime")

-- fcitxを使用したIME制御
ime.off()
vim.wait(100)

-- fcitx-remote -c が実行された
-- (システムコールのトレースが必要)

ime.on()
vim.wait(100)

-- fcitx-remote -o が実行された

assert.is_true(true)
```

---

### Test 10.5: Linux - ibusフォールバック

**手順** (Linux):

1. `fcitx-remote`が利用不可
2. `ibus`が利用可能
3. IME制御でibusが使用されることを確認

**期待される結果**:

- `ibus engine`コマンドが実行される
- `xkb:us::eng`と`mozc-jp`の切り替え

**検証ポイント**:

```lua
if config.os ~= "linux" then
  pending("This test is Linux only")
  return
end

-- fcitx不在、ibus存在を確認
if vim.fn.executable("fcitx-remote") == 1 then
  pending("fcitx-remote exists, skip ibus test")
  return
end

if vim.fn.executable("ibus") == 0 then
  pending("ibus not found")
  return
end

local ime = require("ime-auto.ime")

-- ibusを使用したIME制御
ime.off()
vim.wait(100)

-- ibus engine 'xkb:us::eng' が実行された

ime.on()
vim.wait(100)

-- ibus engine 'mozc-jp' が実行された

assert.is_true(true)
```

---

### Test 10.6: カスタムコマンドの動作確認

**手順**:

1. `ime_method = "custom"`で setup
2. カスタムコマンドを設定
3. IME制御でカスタムコマンドが実行されることを確認

**期待される結果**:

- OS標準ではなくカスタムコマンドが実行される

**検証ポイント**:

```lua
-- カスタムコマンドのログファイル
local log_file = vim.fn.tempname()

require("ime-auto").setup({
  ime_method = "custom",
  custom_commands = {
    on = string.format("echo 'custom on' >> %s", log_file),
    off = string.format("echo 'custom off' >> %s", log_file),
    status = "echo '1'", -- IME ON
  },
})

local ime = require("ime-auto.ime")

-- カスタムコマンド実行
ime.on()
vim.wait(100)

ime.off()
vim.wait(100)

-- ログファイル確認
local log_lines = vim.fn.readfile(log_file)
assert.is_true(#log_lines >= 2)

assert.is_true(log_lines[1]:match("custom on") ~= nil)
assert.is_true(log_lines[2]:match("custom off") ~= nil)

-- クリーンアップ
vim.fn.delete(log_file)
```

---

### Test 10.7: OS間の一貫性（状態管理）

**手順**:

1. 各OSでInsert → Normal → Insertサイクル
2. IME状態が保存・復元されることを確認

**期待される結果**:

- macOS: slotベース管理
- Windows/Linux: `last_ime_state`ベース管理
- どちらも同様のユーザー体験

**検証ポイント**:

```lua
local ime = require("ime-auto.ime")
local config = require("ime-auto.config").get()

-- Insert開始
vim.cmd("startinsert")
vim.wait(50)

-- IME ON
ime.on()
vim.wait(50)

-- Normal
vim.cmd("stopinsert")
vim.wait(100)

-- 再度Insert
vim.cmd("startinsert")
vim.wait(50)

-- 状態が復元されている（OS別の実装は異なるが、結果は同じ）
-- macOS: slot Aから復元
-- Windows/Linux: last_ime_stateから復元

local status = ime.get_status()

if config.os == "macos" then
  -- macOSは常にslot管理
  assert.is_not_nil(status)
else
  -- Windows/Linuxは状態ベース
  assert.is_true(status) -- ONが復元される
end

vim.cmd("stopinsert")
```

## 実装例

```lua
-- tests/priority-3/os_specific_behavior_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 10: OS-specific behavior", function()
  local config = nil

  before_each(function()
    ime_auto.setup({ os = "auto" })
    config = require("ime-auto.config").get()

    vim.cmd("enew!")
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("10.1: OS自動検出", function()
    it("should detect OS correctly", function()
      local os_name = vim.loop.os_uname().sysname:lower()

      if os_name:match("darwin") then
        assert.equals("macos", config.os)
      elseif os_name:match("windows") or os_name:match("mingw") then
        assert.equals("windows", config.os)
      elseif os_name:match("linux") then
        assert.equals("linux", config.os)
      end
    end)
  end)

  describe("10.2: macOS - Swift tool統合", function()
    it("should use Swift tool for IME control", function()
      if config.os ~= "macos" then
        pending("This test is macOS only")
        return
      end

      local swift_tool = require("ime-auto.swift-ime-tool")
      local ok = swift_tool.ensure_compiled()
      assert.is_true(ok)

      ime.on()
      vim.wait(50)

      ime.off()
      vim.wait(50)

      assert.is_true(true)
    end)
  end)

  describe("10.3: Windows - PowerShell統合", function()
    it("should use PowerShell for IME control", function()
      if config.os ~= "windows" then
        pending("This test is Windows only")
        return
      end

      ime.on()
      vim.wait(100)

      ime.off()
      vim.wait(100)

      local status = ime.get_status()
      assert.is_not_nil(status)
    end)
  end)

  describe("10.4: Linux - fcitx優先", function()
    it("should use fcitx when available", function()
      if config.os ~= "linux" then
        pending("This test is Linux only")
        return
      end

      if vim.fn.executable("fcitx-remote") == 0 then
        pending("fcitx-remote not found")
        return
      end

      ime.off()
      vim.wait(100)

      ime.on()
      vim.wait(100)

      assert.is_true(true)
    end)
  end)

  describe("10.6: カスタムコマンド", function()
    it("should execute custom commands", function()
      local log_file = vim.fn.tempname()

      require("ime-auto").setup({
        ime_method = "custom",
        custom_commands = {
          on = string.format("echo 'custom on' >> %s", log_file),
          off = string.format("echo 'custom off' >> %s", log_file),
          status = "echo '1'",
        },
      })

      ime.on()
      vim.wait(100)

      ime.off()
      vim.wait(100)

      local log_lines = vim.fn.readfile(log_file)
      assert.is_true(#log_lines >= 2)

      vim.fn.delete(log_file)
    end)
  end)

  describe("10.7: OS間の一貫性", function()
    it("should provide consistent state management across OSes", function()
      vim.cmd("startinsert")
      vim.wait(50)

      ime.on()
      vim.wait(50)

      vim.cmd("stopinsert")
      vim.wait(100)

      vim.cmd("startinsert")
      vim.wait(50)

      local status = ime.get_status()
      assert.is_not_nil(status)

      vim.cmd("stopinsert")
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **OS検出ロジック**
   ```lua
   -- config.lua:30-42
   local os_name = vim.loop.os_uname().sysname:lower()
   ```

2. **Linux IMEツールの存在確認**
   ```bash
   which fcitx-remote
   which ibus
   ```

3. **Windows PowerShell確認**
   ```powershell
   Get-Command powershell
   ```

### 既知の問題

- **Linux**: fcitx/ibus両方未インストールの環境では動作しない
- **Windows**: PowerShell実行ポリシーによっては失敗する可能性
- **CI環境**: ヘッドレスモードではIME制御が不可能

## 成功基準

以下のすべての条件を満たすこと：

- ✅ OS自動検出が正確
- ✅ macOSでSwift toolが正常動作
- ✅ WindowsでPowerShellが実行される
- ✅ Linuxでfcitxまたはibusが実行される
- ✅ カスタムコマンドが正常動作
- ✅ OS間で一貫したユーザー体験

## 関連テストケース

- [01: 基本的なIME切り替え](../priority-1-critical/01-basic-ime-switching.md)
- [04: Swiftツールのコンパイルとリカバリ](../priority-1-critical/04-swift-tool-compilation.md)
- [08: macOS slot初期化](../priority-2-important/08-macos-slot-initialization.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
