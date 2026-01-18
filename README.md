# ime-auto.nvim

Neovimで日本語入力時のIME（Input Method Editor）を自動的に制御するプラグインです。

## 特徴

- **エスケープシーケンス**: insertモードで全角文字（デフォルト: `ｋｊ`）を入力してnormalモードへ移行
- **IME自動切り替え**: normalモード、visualモード、commandモードでは自動的にIMEをOFF
- **状態の自動記憶**: InsertモードとNormalモードのIME状態を記憶し、次回以降自動復元
- **macOS 完全対応**: 外部ツール不要、組み込みのSwiftツールを使用（初回起動時に自動コンパイル）
- **Windows/Linux 実験的サポート**: PowerShell/fcitx-remote/ibus 経由（未テスト）

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)

**最小設定（推奨）**:
```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
}
```

**エスケープシーケンスを変更する場合**:
```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
  config = function()
    require("ime-auto").setup({
      escape_sequence = "ｊｊ",  -- デフォルトは "ｋｊ"
    })
  end,
}
```

## 使い方

**設定不要で使えます！**

インストール後、普通にNeovimを使うだけでOKです。
- InsertモードとNormalモードのIME状態を自動的に記憶、復元されます
- Google日本語入力、ATOK、Kotoeriなど、どの日本語IMEでも自動対応

### コマンド

- `:ImeAutoEnable` - IME自動切り替えを有効化
- `:ImeAutoDisable` - IME自動切り替えを無効化
- `:ImeAutoToggle` - IME自動切り替えのトグル
- `:ImeAutoStatus` - 現在の状態を表示
- `:ImeAutoListInputSources` - 利用可能な入力ソース一覧を表示（macOS専用、参考用）

## macOS ユーザーへ

macOSでは、初回起動時に専用のSwiftツールが自動的にコンパイルされます。

### 必要なもの

- Xcode Command Line Tools（`swiftc`コマンドが必要）

インストールされていない場合：

```bash
xcode-select --install
```

確認方法：

```bash
swiftc --version
```

## トラブルシューティング

### エスケープシーケンスが動作しない

- 全角文字で入力していることを確認してください
- 入力確定が必要なので、エンター押下が必要です

### macOSでコンパイルエラーが出る

Xcode Command Line Tools をインストールしてください：

```bash
xcode-select --install
```

### その他の問題

デバッグモードを有効にして動作を確認：

```lua
require("ime-auto").setup({ debug = true })
```

`:messages` でログを確認できます。

## 貢献

Issue報告やPull Requestを歓迎します！

開発に関する詳細は以下を参照してください：
- 📖 [CONTRIBUTING.md](CONTRIBUTING.md) - 貢献ガイド（テスト実行方法など）
- 📖 [CLAUDE.md](CLAUDE.md) - 開発ガイド（アーキテクチャ、実装詳細、Claude Code での開発方法）

## ライセンス

MIT License
