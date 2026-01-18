# IME Auto - E2E Manual Test Guide

このドキュメントは、ime-auto.nvimの実際の動作を確認するための手順書です。
vibing.nvimのエージェントがこの手順に従ってテストを実行できます。

## 前提条件

- macOS環境
- Neovim起動済み
- ime-auto.nvimがインストール済み
- 日本語IME（Kotoeri）が利用可能

## テスト環境セットアップ

### 1. プラグインの初期化確認

```vim
" プラグインが読み込まれているか確認
:echo exists('g:loaded_ime_auto')
" 期待値: 1 (true)

" コマンドが使えるか確認
:ImeAutoStatus
" 期待値: "ime-auto: enabled, IME: on/off" のような出力
```

### 2. Swiftツールのコンパイル確認

```vim
" Swiftツールがコンパイルされているか確認
:lua print(vim.fn.filereadable(vim.fn.expand('~/.local/share/nvim/ime-auto/swift-ime')))
" 期待値: 1 (ファイルが存在する)
```

### 3. 利用可能なIMEの確認

```vim
:ImeAutoListInputSources
" 期待値: 入力ソース一覧が表示される
" 例:
"   com.apple.keylayout.ABC
"   com.apple.inputmethod.Kotoeri.Japanese
```

---

## E2Eテストシナリオ

### Test E2E-01: 基本的なIME切り替え（英語→日本語）

**目的**: Insert modeでの日本語IME復元を確認

**手順**:
1. 新しいバッファを開く: `:enew`
2. Insert modeに入る: `i`
3. 日本語IMEに切り替える（Ctrl+Space または ⌘+Space）
4. 何か日本語を入力: `てすと`
5. Normal modeに戻る: `<Esc>`
6. **確認ポイント1**: IMEが英語（ABC）に切り替わっているか？
7. 再度Insert modeに入る: `i`
8. **確認ポイント2**: 日本語IMEに自動復元されているか？
9. 日本語入力できるか確認: `かくにん`

**期待される動作**:
- ✅ Normal modeでIMEが英語になる
- ✅ Insert modeで前回の日本語IMEに戻る
- ✅ エラーが発生しない

**確認方法**（Lua）:
```lua
-- Normal modeでのIME状態確認
vim.cmd("stopinsert")
vim.wait(200)
local ime_status = require("ime-auto.ime").get_status()
print("Normal mode IME:", ime_status)  -- false (英語) が期待値

-- Insert modeでの復元確認
vim.cmd("startinsert")
vim.wait(200)
ime_status = require("ime-auto.ime").get_status()
print("Insert mode IME:", ime_status)  -- true (日本語) が期待値
```

---

### Test E2E-02: スロット永続化の確認

**目的**: Neovim再起動後もIME状態が保持されることを確認

**手順**:
1. Insert modeで日本語IMEを使用
2. Normal modeに戻る
3. Neovimを終了: `:qa`
4. Neovimを再起動
5. 新しいバッファを開く: `:enew`
6. Insert modeに入る: `i`
7. **確認ポイント**: 日本語IMEが復元されているか？

**期待される動作**:
- ✅ 再起動後もInsert modeで日本語IMEが使える

**確認方法**（Bash）:
```bash
# スロットファイルの存在確認
ls -la ~/.local/share/nvim/ime-auto/
# 期待値:
#   saved-ime-a.txt (Insert mode IME)
#   saved-ime-b.txt (Normal mode IME)

# スロットファイルの内容確認
cat ~/.local/share/nvim/ime-auto/saved-ime-a.txt
# 期待値: com.apple.inputmethod.Kotoeri.Japanese など
```

---

### Test E2E-03: 複数バッファでの動作

**目的**: 複数バッファ間でIME状態が正しく管理されることを確認

**手順**:
1. バッファ1を開く: `:enew`
2. Insert modeで英語入力: `i` → `english`
3. Normal modeに戻る: `<Esc>`
4. バッファ2を開く: `:enew`
5. Insert modeで日本語IMEに切り替えて入力: `i` → 日本語ON → `にほんご`
6. Normal modeに戻る: `<Esc>`
7. バッファ1に戻る: `:bprevious`
8. Insert modeに入る: `i`
9. **確認ポイント**: 英語IMEが使われているか？

**期待される動作**:
- ✅ 各バッファで最後に使ったIMEが記憶されている
- ✅ バッファ切り替えでIMEが正しく復元される

---

### Test E2E-04: Command modeでの動作

**目的**: Command modeでslot Aが上書きされないことを確認

**手順**:
1. Insert modeで日本語IME: `i` → 日本語ON → `てすと`
2. Normal modeに戻る: `<Esc>`
3. Command modeに入る: `:`
4. 何かコマンド入力: `echo "test"`
5. Command modeを抜ける: `<Esc>`
6. Insert modeに入る: `i`
7. **確認ポイント**: 日本語IMEが復元されているか？

**期待される動作**:
- ✅ Command modeでIME状態が変わらない
- ✅ Insert modeで日本語IMEが復元される

---

### Test E2E-05: エスケープシーケンス

**目的**: 全角文字でのエスケープシーケンス（ｋｊ）が動作することを確認

**手順**:
1. Insert modeに入る: `i`
2. 日本語IMEに切り替える
3. エスケープシーケンスを入力: `ｋｊ`（全角）
4. **確認ポイント**: Normal modeに戻るか？
5. バッファに`ｋｊ`が残っていないか？

**期待される動作**:
- ✅ `ｋｊ`でNormal modeに戻る
- ✅ バッファに`ｋｊ`が残らない
- ✅ IMEが英語に切り替わる

**確認方法**（Lua）:
```lua
-- バッファ内容確認
local line = vim.api.nvim_get_current_line()
print("Buffer content:", line)
-- 期待値: "ｋｊ" が含まれていない

-- モード確認
local mode = vim.api.nvim_get_mode().mode
print("Current mode:", mode)
-- 期待値: "n" (Normal mode)
```

---

### Test E2E-06: 高速モード切り替え

**目的**: 素早くモード切り替えをしてもエラーが出ないことを確認

**手順**:
1. 以下を素早く繰り返す（5回）:
   - `i` (Insert)
   - `<Esc>` (Normal)
   - `i` (Insert)
   - `<Esc>` (Normal)

**期待される動作**:
- ✅ エラーが発生しない
- ✅ Neovimがフリーズしない
- ✅ IME切り替えが正常に動作する

---

### Test E2E-07: IME状態の手動確認（デバッグ用）

**目的**: 現在のIME状態を直接確認する

```lua
-- 現在のIME ID取得
local swift_tool = require("ime-auto.swift-ime-tool")
local current_ime = swift_tool.get_current()
print("Current IME:", current_ime)

-- スロットの内容確認
local slot_a = vim.fn.readfile(vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-a.txt"))
local slot_b = vim.fn.readfile(vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-b.txt"))
print("Slot A (Insert):", slot_a[1])
print("Slot B (Normal):", slot_b[1])

-- IME状態確認
local ime = require("ime-auto.ime")
local status = ime.get_status()
print("IME Status:", status)  -- true=ON, false=OFF
```

---

## トラブルシューティング

### Swiftツールがコンパイルされない

```bash
# 手動コンパイル
cd ~/.local/share/nvim/ime-auto/
swiftc -o swift-ime ~/path/to/ime-auto.nvim/swift/ime-tool.swift
chmod +x swift-ime

# コンパイラ確認
which swiftc
# なければ: xcode-select --install
```

### IMEが切り替わらない

```lua
-- デバッグログ有効化
require("ime-auto").setup({ debug = true })

-- ログ確認
:messages
```

### スロットファイルが作成されない

```bash
# ディレクトリ確認
ls -la ~/.local/share/nvim/ime-auto/

# 権限確認
ls -la ~/.local/share/nvim/

# 手動作成（必要なら）
mkdir -p ~/.local/share/nvim/ime-auto
chmod 700 ~/.local/share/nvim/ime-auto
```

---

## vibing.nvim向けの実行例

以下はvibing.nvimのエージェントが実行する際のサンプルです：

```lua
-- Test E2E-01を自動実行する例
local function run_test_e2e_01()
  print("=== Test E2E-01: 基本的なIME切り替え ===")

  -- 1. 新しいバッファ
  vim.cmd("enew")

  -- 2. Insert modeに入る
  vim.cmd("startinsert")
  vim.wait(100)

  -- 3. 日本語IMEに切り替え（手動操作が必要）
  print("⚠️  手動操作: 日本語IMEに切り替えてください")
  vim.wait(2000)

  -- 4. Normal modeに戻る
  vim.cmd("stopinsert")
  vim.wait(200)

  -- 5. IME確認
  local ime = require("ime-auto.ime")
  local status_normal = ime.get_status()
  print("Normal mode IME status:", status_normal)
  assert(status_normal == false, "Normal modeではIMEがOFFであるべき")

  -- 6. 再度Insert mode
  vim.cmd("startinsert")
  vim.wait(200)

  -- 7. IME確認
  local status_insert = ime.get_status()
  print("Insert mode IME status:", status_insert)
  -- 日本語IMEなら true になるはず

  print("✅ Test E2E-01 完了")
end

-- 実行
run_test_e2e_01()
```

---

## チェックリスト

テスト実行前に確認：
- [ ] macOS環境
- [ ] Neovim 0.8以上
- [ ] ime-auto.nvimインストール済み
- [ ] Swiftコンパイラ利用可能（`which swiftc`）
- [ ] 日本語IME設定済み
- [ ] vibing.nvim（オプション、自動化する場合）

すべてのE2Eテストを実行：
- [ ] E2E-01: 基本的なIME切り替え
- [ ] E2E-02: スロット永続化
- [ ] E2E-03: 複数バッファでの動作
- [ ] E2E-04: Command modeでの動作
- [ ] E2E-05: エスケープシーケンス
- [ ] E2E-06: 高速モード切り替え
- [ ] E2E-07: 手動デバッグ確認
