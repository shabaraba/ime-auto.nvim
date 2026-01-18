# テストケース 02: 高速モード切り替えでの競合状態

**優先度**: Priority 1 - Critical
**カテゴリ**: パフォーマンス・競合状態
**対象OS**: すべて (macOS, Windows, Linux)

## 概要

このテストは、高速なモード切り替え時にIMEキャッシュとデバウンス機構が正しく協調動作することを検証します。

### テストの重要性

- ✅ **潜在的バグ**: コードレビューで特定された競合状態（信頼度95%）
- ✅ **実用性**: 実際のコーディングでは高速なモード切り替えが頻繁に発生
- ✅ **データ整合性**: キャッシュとデバウンスの協調動作が状態管理に直結

### 発見された問題

**ファイル**: `/lua/ime-auto/ime.lua` (L141-165, L172-193)

**問題シナリオ**:
```
時刻 0ms:   InsertLeave → off_debounced() スケジュール (100ms後実行)
時刻 50ms:  InsertEnter → get_status() がキャッシュから状態取得
時刻 100ms: off_debounced() 実行 → 実際のIME状態変更
```

この場合、50ms時点で取得したキャッシュは古い状態を返す可能性があります。

## 関連ファイル

- `/lua/ime-auto/ime.lua` (L21-30: キャッシュ定義, L141-165: デバウンス実装, L172-193: get_status実装)
- `/lua/ime-auto/init.lua` (L11-33: オートコマンド定義)

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
  debug = true, -- デバッグログ有効化
})
```

## テストステップ

### Test 2.1: デバウンス機構の基本動作

**手順**:

1. Insertモード開始
2. すぐに（10ms以内に）Normalモードに戻る
3. デバウンスタイマーを確認
4. 100ms待機
5. IME状態を確認

**期待される結果**:

- `off_debounced()`が呼ばれる
- 100ms以内は`M.control("off")`が実行されない
- 100ms後にIMEがOFFになる

**検証ポイント**:

```lua
-- デバウンスタイマーの存在確認
-- 注: mode_change_timer はモジュール内部変数のため、
-- テストではシステムコールのカウントで検証
```

---

### Test 2.2: 高速なInsert→Normal→Insert切り替え

**手順**:

1. Insertモード開始（IME=ON想定）
2. 50msでNormalモードへ移行
3. さらに50ms後にInsertモードへ戻る（合計100ms以内）
4. IME状態を確認

**期待される結果**:

- 最初のInsertモードの状態が復元される
- デバウンスによりシステムコールが最小限（理想的には1回）
- キャッシュとの整合性が保たれる

**検証ポイント**:

```lua
-- システムコール回数をカウント
local call_count = 0
local original_control = ime.control
ime.control = function(action)
  if action == "off" or action == "on" then
    call_count = call_count + 1
  end
  return original_control(action)
end

-- テスト実行後
assert(call_count <= 2, "Should minimize system calls with debounce")

ime.control = original_control
```

---

### Test 2.3: キャッシュとデバウンスの競合状態

**手順**:

1. Insertモード開始
2. IME状態をキャッシュに保存（get_status呼び出し）
3. InsertLeave（off_debounced呼び出し）
4. 50ms待機（デバウンス実行前）
5. get_status()を呼び出してキャッシュヒット確認
6. 100ms待機（デバウンス実行）
7. キャッシュを無効化
8. get_status()で最新状態確認

**期待される結果**:

- Step 5でキャッシュからIME=ONが返る（正しい）
- Step 8でIME=OFFが返る（デバウンス実行後）
- 競合状態でもデータ整合性が保たれる

**検証ポイント**:

```lua
-- キャッシュTTLの確認
local ime_state_cache = {
  value = nil,
  timestamp = 0,
  ttl_ms = 500
}

-- タイムスタンプの整合性
local now = vim.loop.now()
assert((now - timestamp) < 500, "Cache should be valid")
```

---

### Test 2.4: 連続した高速モード切り替え（ストレステスト）

**手順**:

1. 10回の高速Insert→Normal切り替え（各50ms間隔）
2. 最終的なIME状態を確認
3. システムコール回数を確認

**期待される結果**:

- 各切り替えでデバウンスタイマーがキャンセル・再設定される
- 最終的にIMEがOFFになる
- システムコールが大幅に削減される（理想: 1-2回）

**検証ポイント**:

```lua
-- タイマーの正しいキャンセル
if mode_change_timer then
  vim.fn.timer_stop(mode_change_timer) -- 既存タイマー停止
end

-- 新規タイマー設定
mode_change_timer = vim.fn.timer_start(100, callback)
```

---

### Test 2.5: キャッシュ有効期限切れの挙動

**手順**:

1. get_status()でキャッシュ作成
2. 600ms待機（TTL=500msを超過）
3. get_status()を再度呼び出し
4. キャッシュミスを確認
5. システムコールが実行されることを確認

**期待される結果**:

- 500ms以内: キャッシュヒット、システムコールなし
- 500ms超過: キャッシュミス、システムコール実行
- 新しいキャッシュが作成される

**検証ポイント**:

```lua
-- キャッシュTTL検証
local first_call = vim.loop.now()
ime.get_status() -- キャッシュ作成

vim.wait(600)

local second_call = vim.loop.now()
ime.get_status() -- キャッシュ再取得

assert((second_call - first_call) > 500, "Should exceed TTL")
```

## 実装例

```lua
-- tests/priority-1/rapid_mode_switching_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 02: Rapid mode switching", function()
  local original_control = nil
  local call_count = 0

  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")

    -- システムコールのスパイ設定
    call_count = 0
    original_control = ime.control
    ime.control = function(action)
      if action == "off" or action == "on" then
        call_count = call_count + 1
      end
      return original_control(action)
    end
  end)

  after_each(function()
    vim.cmd("bdelete!")

    -- スパイのクリーンアップ
    if original_control then
      ime.control = original_control
    end
  end)

  describe("2.1: デバウンス機構の基本動作", function()
    it("should debounce IME off calls", function()
      vim.cmd("startinsert")
      vim.wait(50)

      -- すぐにNormalモードへ
      vim.cmd("stopinsert")

      -- デバウンス時間内ではシステムコールされない
      vim.wait(50) -- 50ms < 100ms
      local early_call_count = call_count

      -- デバウンス後はシステムコール実行
      vim.wait(100) -- 合計150ms > 100ms
      local late_call_count = call_count

      assert.is_true(late_call_count > early_call_count)
    end)
  end)

  describe("2.2: 高速なInsert→Normal→Insert切り替え", function()
    it("should handle rapid mode switching without data corruption", function()
      -- 初回Insert
      vim.cmd("startinsert")
      vim.wait(50)
      local initial_state = ime.get_status()

      -- Normal
      vim.cmd("stopinsert")
      vim.wait(50) -- デバウンス実行前

      -- 再度Insert
      vim.cmd("startinsert")
      vim.wait(150) -- デバウンス実行完了待ち

      local restored_state = ime.get_status()

      -- 状態整合性の確認
      -- macOSの場合は常にON、他OSは初回状態の復元
      local config = require("ime-auto.config").get()
      if config.os ~= "macos" then
        assert.equals(initial_state, restored_state)
      end

      vim.cmd("stopinsert")
    end)

    it("should minimize system calls with debounce", function()
      call_count = 0

      -- 高速切り替え
      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")
      vim.wait(50)
      vim.cmd("startinsert")
      vim.wait(50)
      vim.cmd("stopinsert")

      vim.wait(150) -- すべてのデバウンス実行待ち

      -- システムコールが削減されているか
      -- 理想: 2-3回（on, off, デバウンスされたoff）
      assert.is_true(call_count <= 4)
    end)
  end)

  describe("2.3: キャッシュとデバウンスの競合状態", function()
    it("should maintain cache consistency during debounced calls", function()
      vim.cmd("startinsert")
      vim.wait(50)

      -- キャッシュ作成
      local cached_status = ime.get_status()

      -- デバウンスされたoff呼び出し
      vim.cmd("stopinsert")
      vim.wait(50) -- デバウンス実行前

      -- キャッシュからの取得（まだ有効）
      local during_debounce_status = ime.get_status()
      assert.equals(cached_status, during_debounce_status)

      -- デバウンス実行後
      vim.wait(100)

      -- キャッシュ無効化のため、500ms待機は不要
      -- 新しい状態を強制取得するにはキャッシュクリアが必要
      -- （実装上はキャッシュクリア機能がないため、TTL待機）
    end)
  end)

  describe("2.4: 連続した高速モード切り替え", function()
    it("should handle 10 rapid switches", function()
      call_count = 0

      for i = 1, 10 do
        vim.cmd("startinsert")
        vim.wait(25)
        vim.cmd("stopinsert")
        vim.wait(25)
      end

      -- すべてのデバウンス実行待ち
      vim.wait(200)

      -- システムコールが大幅に削減されている
      -- デバウンスなし: 20回（各on/off）
      -- デバウンスあり: ~2-5回
      assert.is_true(call_count < 10)
    end)
  end)

  describe("2.5: キャッシュ有効期限切れの挙動", function()
    it("should expire cache after TTL", function()
      call_count = 0

      -- キャッシュ作成
      ime.get_status()
      local cached_call_count = call_count

      -- キャッシュヒット（TTL内）
      vim.wait(400)
      ime.get_status()
      assert.equals(cached_call_count, call_count) -- コール増加なし

      -- キャッシュ期限切れ（TTL超過）
      vim.wait(200) -- 合計600ms
      ime.get_status()
      assert.is_true(call_count > cached_call_count) -- 新規コール
    end)
  end)
end)
```

## トラブルシューティング

### テスト失敗時の確認事項

1. **デバウンス時間の確認**
   ```lua
   -- ime.lua内の定数
   local MODE_CHANGE_DEBOUNCE_MS = 100
   ```

2. **キャッシュTTLの確認**
   ```lua
   -- ime.lua内のキャッシュ設定
   local ime_state_cache = {
     ttl_ms = 500
   }
   ```

3. **タイマーの実行状況**
   ```lua
   -- デバッグモードで確認
   require("ime-auto").setup({ debug = true })
   ```

4. **vim.wait()の精度**
   - Neovimのイベントループにより、正確な待機時間が保証されない場合がある
   - マージン（+50ms程度）を考慮してアサーション

### 既知の問題

- **タイミング依存**: CI環境ではタイマーの精度が低下する可能性
- **macOS特有**: トグルベースのため、状態復元の検証が他OSと異なる

## 成功基準

以下のすべての条件を満たすこと：

- ✅ デバウンス機構が100ms正しく動作する
- ✅ 高速モード切り替えで状態整合性が保たれる
- ✅ システムコールが適切に削減される（10回切り替えで<10回コール）
- ✅ キャッシュが500ms TTLで正しく動作する
- ✅ キャッシュとデバウンスの競合状態が発生しない

## 関連テストケース

- [01: 基本的なIME切り替え](./01-basic-ime-switching.md)
- [05: IME状態の保存と復元](./05-ime-state-persistence.md)
- [06: リソースクリーンアップ](../priority-2-important/06-resource-cleanup.md)

---

**作成日**: 2026-01-18
**最終更新**: 2026-01-18
**実装状態**: 未実装
