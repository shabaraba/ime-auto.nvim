# ime-auto.nvim

> Neovim で日本語入力時の IME を自動制御するプラグイン

Neovim で日本語を快適に編集するために、モード切り替え時の IME 状態を自動管理します。

## ✨ 特徴

- 🎯 **ゼロコンフィグ**: インストールするだけで動作、設定不要
- ⌨️ **エスケープシーケンス**: 全角 `ｋｊ` で Insert → Normal へスムーズに移行
- 🔄 **自動切り替え**: モード変更時に IME を自動 ON/OFF
- 💾 **状態記憶**: Insert/Normal モードの IME 状態を永続化
- 🍎 **macOS ネイティブ**: コンパイル不要、Universal Binary 同梱（Intel/Apple Silicon 対応）
- 🌐 **Windows/Linux**: 実験的サポート（PowerShell/fcitx-remote/ibus）

## 📦 必要環境

- Neovim >= 0.8.0

## 🚀 インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "shabaraba/ime-auto.nvim",
  event = "InsertEnter",
}
```

**設定不要で動作します！** インストールするだけで IME の自動制御が有効になります。

<details>
<summary>エスケープシーケンスをカスタマイズする場合</summary>

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

</details>

## 📚 使い方

詳細なドキュメントは Neovim 内で参照できます：
```vim
:help ime-auto
```

### 基本動作

インストール後、特別な操作は不要です：

- **Insert モード**: 前回の IME 状態を自動復元
- **Normal モード**: IME を自動 OFF
- **Insert モード復帰**: IME を自動 ON（前回が ON だった場合）

### コマンド

| コマンド | 説明 |
|---------|------|
| `:ImeAutoEnable` | IME 自動切り替えを有効化 |
| `:ImeAutoDisable` | IME 自動切り替えを無効化 |
| `:ImeAutoToggle` | 有効/無効を切り替え |
| `:ImeAutoStatus` | 現在の状態を表示 |
| `:ImeAutoListInputSources` | 入力ソース一覧（macOS のみ） |

### エスケープシーケンス

全角文字 `ｋｊ` を入力すると、Insert モードから Normal モードへ移行します：

```
Insert モードで日本語入力中
  ↓
「ｋｊ」と入力（全角）
  ↓
自動的に Normal モードへ移行
```

**注意**:
- 半角の `kj` では動作しません（全角文字が必要）
- 入力確定（エンター）が必要です

## 🔧 トラブルシューティング

### エスケープシーケンスが動作しない

- ✅ 全角文字 `ｋｊ` で入力していることを確認
- ✅ 入力を確定（エンター）してください

### デバッグモード

問題が解決しない場合、デバッグモードで詳細を確認：

```lua
require("ime-auto").setup({ debug = true })
```

`:messages` でログを確認できます。

## 🤝 CONTRIBUTING

Issue 報告や Pull Request を歓迎します！

開発に関する詳細：
- 📖 [CONTRIBUTING.md](CONTRIBUTING.md) - 貢献ガイド
- 📖 [CLAUDE.md](CLAUDE.md) - 開発ガイド（アーキテクチャ、実装詳細）

## 📄 LICENSE

MIT License

