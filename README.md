# ime-auto.nvim

Neovimで日本語入力時のIME（Input Method Editor）を自動的に制御するプラグインです。

## 特徴

- insertモードでのエスケープシーケンス（デフォルト: `ｋｊ`）でnormalモードへ移行
- normalモード、visualモード、commandモードでは自動的にIMEをOFF
- insertモードに入る際、前回のIME状態を自動復元
- macOS、Windows、Linuxに対応
- OS標準機能を使用（外部ツール不要）
- macOSでは高速な外部CLIツール（macime、macism、im-select）にも対応

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
      macos_ime_tool = nil,     -- macOS: nil (osascript), "macime", "macism", "im-select"
      debug = false,            -- デバッグモード
    })
  end,
}
```

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

### macOS: 外部CLIツールの使用（高速化）

デフォルトの`osascript`は起動に時間がかかるため、より高速な外部CLIツールを使用できます：

#### macimeの使用（推奨：10-60%高速化）

```lua
require("ime-auto").setup({
  macos_ime_tool = "macime",
})
```

インストール: [riodelphino/macime](https://github.com/riodelphino/macime)

#### macismの使用（CJKV入力に最適）

```lua
require("ime-auto").setup({
  macos_ime_tool = "macism",
})
```

インストール: [laishulu/macism](https://github.com/laishulu/macism)

#### im-selectの使用

```lua
require("ime-auto").setup({
  macos_ime_tool = "im-select",
})
```

インストール: [daipeihust/im-select](https://github.com/daipeihust/im-select)

#### カスタム入力ソースIDの設定

システムの入力ソースIDが標準と異なる場合：

```lua
require("ime-auto").setup({
  macos_ime_tool = "macime",
  macos_input_source_en = "com.apple.keylayout.US",  -- 英語入力ソースID
  macos_input_source_ja = "com.apple.inputmethod.Kotoeri.Hiragana",  -- 日本語入力ソースID
})
```

入力ソースIDを確認するには、ターミナルで以下を実行：
```bash
# macimeの場合
macime list

# macismの場合
macism

# im-selectの場合
im-select
```

## コマンド

- `:ImeAutoEnable` - IME自動切り替えを有効化
- `:ImeAutoDisable` - IME自動切り替えを無効化
- `:ImeAutoToggle` - IME自動切り替えのトグル
- `:ImeAutoStatus` - 現在の状態を表示

## 動作原理

1. **エスケープシーケンス**: insertモードで設定された全角文字列（例：`ｋｊ`）を入力するとnormalモードに移行
2. **IME制御**: 各OS標準の方法でIMEを制御
   - macOS: `osascript`を使用（デフォルト）、または高速な外部CLIツール（macime、macism、im-select）
   - Windows: PowerShellを使用
   - Linux: `fcitx-remote`または`ibus`を使用（インストール済みの場合）
3. **パフォーマンス最適化**: IME切り替え時の遅延を最小化するため、不要な処理をスキップ

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
       on = "im-select com.google.inputmethod.Japanese.base",
       off = "im-select com.apple.keylayout.ABC",
     },
   })
   ```

### エスケープシーケンスが動作しない

- 全角文字で入力していることを確認してください（`ｋｊ`は全角です）
- タイムアウトを長めに設定してみてください：
  ```lua
  require("ime-auto").setup({ escape_timeout = 500 })
  ```

### IME切り替えにラグがある（macOS）

より高速な外部CLIツールを使用することで改善できます：

```lua
require("ime-auto").setup({
  macos_ime_tool = "macime",  -- 推奨：10-60%高速化
})
```

詳細は「macOS: 外部CLIツールの使用（高速化）」セクションを参照してください。

## ライセンス

MIT License

## 貢献

Issue報告やPull Requestを歓迎します！