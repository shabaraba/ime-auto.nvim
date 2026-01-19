# IME状態不一致問題のデバッグ方法

## 問題の症状

- メニューバーのIME表示: 日本語
- 実際のIME状態: 英字しか入力できない
- 発生タイミング: 数回のモード切り替え後

## デバッグログの有効化

Swift IMEツールには詳細なデバッグログ機能が実装されています。

### 1. 環境変数を設定してNeovimを起動

```bash
# デバッグログを有効化
export IME_AUTO_DEBUG=1

# Neovimを起動
nvim
```

### 2. ログファイルの場所

デバッグログは以下に出力されます：
```
~/.local/share/nvim/ime-auto/debug.log
```

### 3. リアルタイムでログを監視

別のターミナルで以下を実行：
```bash
tail -f ~/.local/share/nvim/ime-auto/debug.log
```

## デバッグ手順

### ステップ1: 初期状態を確認

```bash
# スロットファイルをクリア
rm -f ~/.local/share/nvim/ime-auto/saved-ime-*.txt

# デバッグログをクリア
rm -f ~/.local/share/nvim/ime-auto/debug.log

# 現在のIME IDを確認
./bin/swift-ime
```

### ステップ2: Neovimで問題を再現

```bash
# デバッグモードで起動
export IME_AUTO_DEBUG=1
nvim test.txt
```

Neovim内で：
```vim
" プラグインをセットアップ
:lua require("ime-auto").setup({ debug = true })

" Insert ↔ Normal を3-4回繰り返す
" - 'i' で Insertモード
" - '<Esc>' で Normalモード

" 問題が発生したら、ログを確認
:!cat ~/.local/share/nvim/ime-auto/debug.log
:!cat ~/.local/share/nvim/ime-auto/saved-ime-a.txt
:!cat ~/.local/share/nvim/ime-auto/saved-ime-b.txt
```

### ステップ3: ログを分析

デバッグログには以下の情報が含まれます：

```
[時刻] [toggle-from-insert] START: current=com.google.inputmethod.Japanese.base
[時刻] [toggle-from-insert] Saved to slot A=com.google.inputmethod.Japanese.base
[時刻] [toggle-from-insert] Target=com.apple.keylayout.ABC (from slot B or default)
[時刻] [switchToInputSource] Found target source com.apple.keylayout.ABC, calling TISSelectInputSource
[時刻] [switchToInputSource] Switch verified on first check
[時刻] [toggle-from-insert] SUCCESS: switched to com.apple.keylayout.ABC
```

### 確認ポイント

1. **切り替えのタイミング**
   - `Switch verified on first check` → 50msで成功
   - `Switch verified on retry N` → リトライで成功
   - `FAILED after all retries` → 200ms経っても失敗

2. **スロットの状態**
   ```bash
   cat ~/.local/share/nvim/ime-auto/saved-ime-a.txt  # Insertモードで使うIME
   cat ~/.local/share/nvim/ime-auto/saved-ime-b.txt  # Normalモードで使うIME
   ```

3. **現在のIME状態**
   ```bash
   ./bin/swift-ime  # 現在のIME IDを取得
   ```

## よくある問題パターン

### パターン1: 切り替えが常に失敗

ログに `FAILED after all retries` が頻繁に出る場合：
- **原因**: 待機時間が不足
- **対策**: 待機時間を延長（50ms → 100ms）

### パターン2: スロットAとBが同じIME

```bash
$ cat ~/.local/share/nvim/ime-auto/saved-ime-a.txt
com.google.inputmethod.Japanese.base
$ cat ~/.local/share/nvim/ime-auto/saved-ime-b.txt
com.google.inputmethod.Japanese.base
```

- **原因**: 切り替え完了前に次の処理が実行された
- **ログ確認**: `toggle-from-normal` の `current=` と `target=` が同じになっている

### パターン3: メニューバーとIME状態が不一致

ログ上は成功しているのに実際の入力ができない場合：
- **原因**: Input Source IDは変わったが、Input Modeが切り替わっていない
- **これはCarbon APIの制限**: Input Source内のモード（ひらがな/英数）は制御できない

## 問題が解決しない場合

以下の情報を開発者に共有してください：

1. デバッグログ全体
   ```bash
   cat ~/.local/share/nvim/ime-auto/debug.log
   ```

2. スロットの内容
   ```bash
   cat ~/.local/share/nvim/ime-auto/saved-ime-a.txt
   cat ~/.local/share/nvim/ime-auto/saved-ime-b.txt
   ```

3. 利用可能なInput Sourceリスト
   ```bash
   ./bin/swift-ime list
   ```

4. macOSとIMEのバージョン
   ```bash
   sw_vers
   # 使用しているIME（Google Japanese Input, macOS標準日本語IMEなど）
   ```

5. 再現手順
   - どのモード遷移で問題が発生するか
   - 何回目の切り替えで発生するか
   - 特定のInput Sourceの組み合わせで発生するか

## 高度なデバッグ

### Swiftツールを直接実行

```bash
export IME_AUTO_DEBUG=1

# 現在のIMEを確認
./bin/swift-ime

# 日本語IMEに切り替え
./bin/swift-ime com.google.inputmethod.Japanese.base

# toggle-from-insertを実行
./bin/swift-ime toggle-from-insert

# toggle-from-normalを実行
./bin/swift-ime toggle-from-normal

# ログを確認
cat ~/.local/share/nvim/ime-auto/debug.log
```

### ログのリアルタイム監視

```bash
# ターミナル1: ログ監視
export IME_AUTO_DEBUG=1
tail -f ~/.local/share/nvim/ime-auto/debug.log

# ターミナル2: Neovimで操作
nvim
```

## 既知の制限事項

1. **Carbon APIの非同期性**
   - `TISSelectInputSource()` は非同期で実行される
   - 50ms〜200msの待機とリトライで対応済み

2. **Input Mode制御の不可**
   - Input Source ID（例: `com.google.inputmethod.Japanese.base`）は制御可能
   - Input Mode（ひらがな/英数）は制御不可
   - これはCarbon APIの仕様

3. **Google Japanese Inputの特殊性**
   - 複数のInput Source ID を持つ場合がある
   - `.base` サフィックスの有無で挙動が異なる可能性
