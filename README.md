# ime-auto.nvim

Neovimで日本語入力時のIME（Input Method Editor）を自動的に制御するプラグインです。

## 特徴

- **エスケープシーケンス機能**: insertモードで全角文字列（デフォルト: `ｋｊ`）を入力してnormalモードへスムーズに移行
- **IME自動切り替え**: normalモード、visualモード、commandモードでは自動的にIMEをOFF
- **スロットベース状態管理**: InsertモードとNormalモードのIME状態を永続化し、モード切り替え時に自動トグル
- **クロスプラットフォーム対応**: macOS、Windows、Linuxに対応
- **macOSでは外部ツール不要**: 組み込みのSwiftベースIMEツールを使用（Carbon API経由）
- **高速で信頼性の高いIME制御**: キャッシング・デバウンス処理による最適化
- **セキュア**: Path Traversal攻撃・インジェクション攻撃を防止

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)

**最小設定（推奨）**:
```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
}
```

**カスタマイズする場合**:
```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
  config = function()
    require("ime-auto").setup({
      escape_sequence = "ｊｊ",  -- エスケープシーケンスを変更したい場合のみ
    })
  end,
}
```

<details>
<summary>全設定オプション（通常は不要）</summary>

```lua
require("ime-auto").setup({
  escape_sequence = "ｋｊ",  -- エスケープシーケンス（全角文字）
  escape_timeout = 200,      -- タイムアウト（ミリ秒）
  os = "auto",              -- OS設定: "auto", "macos", "windows", "linux"
  ime_method = "builtin",   -- IME制御方法: "builtin", "custom"
  debug = false,            -- デバッグモード
})
```

</details>

## 初回セットアップ

**設定不要で使えます！**

プラグインをインストールして、普通にNeovimを使うだけでOKです。
- InsertモードとNormalモードのIME状態を自動的に記憶
- 次回以降は自動的に復元されます
- Google日本語入力、ATOK、Kotoeriなど、どの日本語IMEでも自動対応

## 設定

### エスケープシーケンスのカスタマイズ

```lua
require("ime-auto").setup({
  escape_sequence = "ｊｊ",  -- デフォルトは "ｋｊ"
})
```

### カスタムIME制御コマンド

特殊なIME環境の場合、カスタムコマンドを設定できます：

```lua
require("ime-auto").setup({
  ime_method = "custom",
  custom_commands = {
    on = "your-ime-on-command",
    off = "your-ime-off-command",
    status = "your-ime-status-command",  -- 戻り値が "1" または "true" の場合、IME ONと判定
  },
})
```

### OS別の設定

自動検出がうまくいかない場合は、明示的にOSを指定できます：

```lua
require("ime-auto").setup({
  os = "macos",  -- "macos", "windows", "linux"
})
```

## コマンド

### 基本コマンド

- `:ImeAutoEnable` - IME自動切り替えを有効化
- `:ImeAutoDisable` - IME自動切り替えを無効化
- `:ImeAutoToggle` - IME自動切り替えのトグル
- `:ImeAutoStatus` - 現在の状態を表示
- `:ImeAutoListInputSources` - 利用可能な入力ソース一覧を表示（macOS専用、参考用）

## アーキテクチャ

### モジュール構成

```
ime-auto.nvim/
├── lua/ime-auto/
│   ├── init.lua              # エントリーポイント・autocmd登録
│   ├── config.lua            # 設定管理・OS自動検出
│   ├── ime.lua               # IME制御コアロジック（キャッシング・デバウンス）
│   ├── escape.lua            # エスケープシーケンス実装（InsertCharPre）
│   ├── swift-ime-tool.lua    # Swift統合レイヤー（遅延コンパイル）
│   ├── ui.lua                # UI/ダイアログ（入力ソース選択）
│   └── utils.lua             # ユーティリティ関数
├── swift/
│   └── ime-tool.swift        # macOS IME制御（Carbon API）
└── plugin/
    └── ime-auto.lua          # プラグイン初期化
```

### 依存関係マップ

```
init.lua (エントリーポイント)
 ├─ config.lua (設定管理)
 ├─ ime.lua (IME制御)
 │   ├─ swift-ime-tool.lua (macOS Swift統合)
 │   │   └─ swift/ime-tool.swift (Carbon API)
 │   ├─ PowerShell (Windows)
 │   └─ fcitx-remote/ibus (Linux)
 ├─ escape.lua (エスケープシーケンス)
 ├─ ui.lua (UI/ダイアログ)
 └─ utils.lua (ユーティリティ)
```

## 動作原理

### 1. エスケープシーケンス処理

**実装**: `lua/ime-auto/escape.lua`

```
1. InsertCharPre イベント発火
   ↓
2. 入力文字が escape_sequence の1文字目か判定
   ├─ YES → pending_char に保存、タイマー開始
   └─ NO → pending_char クリア
   ↓
3. 2文字目が入力されたか判定（escape_timeout 内）
   ├─ YES → バッファから escape_sequence を削除
   │         IME状態を保存してnormalモードへ移行
   └─ NO → タイムアウトでリセット
```

**エッジケース処理**:
- マルチバイト文字境界: `vim.fn.strchars()` / `vim.fn.strcharpart()` で安全に処理
- タイムアウト管理: デフォルト200ms、カスタマイズ可能
- タイマークリーンアップ: `vim.fn.timer_stop()` で確実に停止

### 2. IME自動切り替え

**実装**: `lua/ime-auto/ime.lua`

```
1. InsertEnter/InsertLeave autocmd 発火
   ↓
2. IME制御関数を呼び出し
   ├─ macOS → swift-ime toggle-from-{insert|normal}
   ├─ Windows → PowerShell IME制御
   └─ Linux → fcitx-remote/ibus
   ↓
3. 状態をスロットに保存/復元
```

**パフォーマンス最適化**:
- **IME状態キャッシュ**: 500ms TTLでsystem call削減
- **デバウンス処理**: モード変更を100msデバウンス（連続切り替え時の負荷軽減）

### 3. スロットベース状態管理

**実装**: `swift/ime-tool.swift`

**スロット設計**:
```
Slot A (~/.local/share/nvim/ime-auto/saved-ime-a.txt)
  └─ Insert モードのIME状態（例: com.apple.inputmethod.Kotoeri.Japanese）

Slot B (~/.local/share/nvim/ime-auto/saved-ime-b.txt)
  └─ Normal モードのIME状態（例: com.apple.keylayout.ABC）
```

**状態遷移フロー**:
```
Insert → Normal 遷移:
  1. 現在のIME IDをSlot Aに保存
  2. Slot BのIME IDを読み込み
  3. Slot BのIMEに切り替え（なければABC）

Normal → Insert 遷移:
  1. 現在のIME IDをSlot Bに保存
  2. Slot AのIME IDを読み込み
  3. Slot AのIMEに切り替え
```

## macOSの組み込みSwiftツールについて

ime-auto.nvimは、macOSでIME切り替えを行うための専用Swiftツールを内蔵しています。

### 技術仕様

- **API**: macOS Carbon Framework の Text Input Services API
  - `TISCopyCurrentKeyboardInputSource()` - 現在の入力ソース取得
  - `TISSelectInputSource()` - 入力ソース切り替え
- **コンパイル**: システムSwiftコンパイラ（`swiftc`）を使用
- **初回起動時に自動コンパイル**: `~/.local/share/nvim/ime-auto/swift-ime`に生成
- **遅延コンパイル**: mtimeベースの自動リコンパイル検出
- **自動状態管理**: 2つのスロット（slot A/B）でInsert/NormalモードのIME状態を永続化

### Swift ツールコマンド

| コマンド | 説明 | 実装 |
|---------|------|------|
| （引数なし） | 現在のIME IDを返す | Carbon API |
| `list` | 利用可能な入力ソース一覧 | TISCreateInputSourceList |
| `toggle-from-insert` | Insert→Normal切り替え | Slot A/B トグル |
| `toggle-from-normal` | Normal→Insert切り替え | Slot A/B トグル |
| `save-insert` | Slot Aに保存 | ファイル書き込み |
| `save-normal` | Slot Bに保存 | ファイル書き込み |

### セキュリティ対策

- **Path Traversal防止**: スロット名を正規表現 `^[a-zA-Z0-9_-]+$` で検証
- **インジェクション攻撃防止**: IME ID フォーマット検証 `^[%w%.%-_]+$`
- **ファイルパーミッション**:
  - ディレクトリ: 0700（所有者のみアクセス可）
  - ファイル: 0600（所有者のみ読み書き可）

### swiftcが見つからない場合

`swiftc`コマンドがシステムにない場合、以下のコマンドでXcode Command Line Toolsをインストールしてください：

```bash
xcode-select --install
```

インストール後、以下のコマンドで確認できます：

```bash
swiftc --version
```

## トラブルシューティング

### IMEが切り替わらない

1. デバッグモードを有効にして動作を確認：
   ```lua
   require("ime-auto").setup({ debug = true })
   ```

2. OS設定を明示的に指定：
   ```lua
   require("ime-auto").setup({ os = "macos" })  -- お使いのOSに合わせて変更
   ```

3. カスタムコマンドを使用：
   ```lua
   require("ime-auto").setup({
     ime_method = "custom",
     custom_commands = {
       on = "your-custom-ime-on-command",
       off = "your-custom-ime-off-command",
     },
   })
   ```

### エスケープシーケンスが動作しない

- 全角文字で入力していることを確認してください（`ｋｊ`は全角です）
- タイムアウトを長めに設定してみてください：
  ```lua
  require("ime-auto").setup({ escape_timeout = 500 })
  ```

### macOSでSwiftツールのコンパイルに失敗する

Swiftコンパイラがインストールされていない可能性があります。以下のコマンドで確認：

```bash
swiftc --version
```

Xcodeまたは Xcode Command Line Tools をインストールしてください：

```bash
xcode-select --install
```

## テスト

### 単体テスト（Unit Tests）

Plenary.nvimを使った自動テストを実行：

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }" \
  -c "qa!"
```

**テストカバレッジ**:
- ✅ 基本的なIME切り替え（8テスト）
- ✅ 高速モード切り替え（6テスト）
- ✅ マルチバイト文字境界（13テスト）

### E2Eテスト / 動作確認テスト

#### 自動テスト（vibing.nvim推奨）

vibing.nvimを使った自動実行：

```vim
:source tests/e2e/vibing_execution_script.lua
```

または、Luaから直接実行：

```lua
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"
local e2e = require("tests.e2e.vibing_test_runner")
e2e.run_all_tests()
```

#### 手動テスト

実際のIME切り替え動作を確認する場合は、以下のドキュメントを参照：

- 📖 **[MANUAL_TEST_GUIDE.md](tests/e2e/MANUAL_TEST_GUIDE.md)** - 詳細なテスト手順
- 📖 **[VIBING_EXECUTION_GUIDE.md](tests/e2e/VIBING_EXECUTION_GUIDE.md)** - vibing.nvim向け実行ガイド

**主なテストシナリオ**:
- E2E-01: 基本的なIME切り替え（英語→日本語）
- E2E-02: スロット永続化（再起動後も保持）
- E2E-03: 複数バッファでの動作
- E2E-04: Command modeでの動作
- E2E-05: エスケープシーケンス（ｋｊ）
- E2E-06: 高速モード切り替え

## 技術的な詳細

### 設計パターン

1. **遅延初期化**: Swiftツールは初回実行時のみコンパイル
2. **キャッシング戦略**: IME状態を500ms TTLでキャッシュ
3. **デバウンス**: モード変更を100msデバウンス
4. **セキュリティファースト**: 入力検証・パーミッション制限を徹底

### プラットフォーム別IME制御

| OS | 制御方法 | 実装 |
|----|---------|------|
| macOS | Carbon API（Swift） | `swift/ime-tool.swift` |
| Windows | PowerShell | `ime.lua` の `ime_control_windows()` |
| Linux | fcitx-remote/ibus | `ime.lua` の `ime_control_linux()` |

## ライセンス

MIT License

## 貢献

Issue報告やPull Requestを歓迎します！

## 関連プロジェクト

- [vibing.nvim](https://github.com/shabaraba/vibing.nvim) - Claude AI統合Neovimプラグイン（ime-auto.nvimのE2Eテストに使用）
