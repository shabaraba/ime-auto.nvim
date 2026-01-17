# ime-auto.nvim

Neovimで日本語入力時のIME（Input Method Editor）を自動的に制御するプラグインです。

## 特徴

- insertモードでのエスケープシーケンス（デフォルト: `ｋｊ`）でnormalモードへ移行
- normalモード、visualモード、commandモードでは自動的にIMEをOFF
- insertモードに入る際、前回のIME状態を自動復元
- macOS、Windows、Linuxに対応
- **macOSでは外部ツール不要**：組み込みのSwiftベースIMEツールを使用
- 高速で信頼性の高いIME切り替え

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
  config = function()
    require("ime-auto").setup({
      -- オプション設定（デフォルト値）
      escape_sequence = "ｋｊ",  -- エスケープシーケンス（全角文字）
      escape_timeout = 200,      -- タイムアウト（ミリ秒）
      os = "auto",              -- OS設定: "auto", "macos", "windows", "linux"
      ime_method = "builtin",   -- IME制御方法: "builtin", "custom"
      debug = false,            -- デバッグモード
    })
  end,
}
```

## 初回セットアップ

**設定不要で使えます！**

プラグインをインストールして、普通にNeovimを使うだけでOKです。
- InsertモードとNormalモードのIME状態を自動的に記憶
- 次回以降は自動的に復元されます
- Google日本語入力、ATOK、Kotoeriなど、どの日本語IMEでも自動対応

## 設定

### 基本設定

```lua
require("ime-auto").setup({
  escape_sequence = "ｊｊ",  -- エスケープシーケンスを変更
  escape_timeout = 300,      -- タイムアウトを長めに設定
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

## 動作原理

1. **エスケープシーケンス**: insertモードで設定された全角文字列（例：`ｋｊ`）を入力するとnormalモードに移行
2. **IME制御**: 各OS標準の方法でIMEを制御
   - macOS: 組み込みのSwiftツール（初回起動時に自動コンパイル）
   - Windows: PowerShellを使用
   - Linux: `fcitx-remote`または`ibus`を使用（インストール済みの場合）
3. **状態管理**: 2つのIME状態（InsertモードとNormalモード）を自動保存し、モード切り替え時にトグル

## macOSの組み込みSwiftツールについて

ime-auto.nvimは、macOSでIME切り替えを行うための専用Swiftツールを内蔵しています：

- **システムSwiftコンパイラを使用**: macOSの`swiftc`コマンドが必要（通常、Xcode Command Line Toolsに含まれます）
- **初回起動時に自動コンパイル**: `~/.local/share/nvim/ime-auto/swift-ime`に生成
- **高速で信頼性が高い**: macOSのCarbon APIを直接使用
- **自動状態管理**: InsertモードとNormalモードのIME状態を2つのスロット（slot A/B）に保存し、モード切り替え時に自動トグル
- **設定不要**: 使い始めた瞬間から、あなたのIME使用パターンを学習して記憶

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

## ライセンス

MIT License

## 貢献

Issue報告やPull Requestを歓迎します！
