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

### Windows（実験的サポート）

Windows では PowerShell 経由で IME (Microsoft IME の日本語入力) を制御します。

**動作確認手順（Windows実機）**:

1. `require("ime-auto").setup({ debug = true })` を設定して Neovim を起動
2. IME を日本語入力（かな入力）に切り替えた状態で `:lua require("ime-auto.ime").control("status")` を実行し、`true` が返ることを確認
3. `:lua require("ime-auto.ime").control("off")` を実行し、IME が英数入力に切り替わることを確認。再度 `off` を実行しても状態が変化しない（決定的）ことを確認
4. `:lua require("ime-auto.ime").control("on")` を実行し、IME が日本語入力に戻ることを確認。再度 `on` を実行しても状態が変化しない（決定的）ことを確認
5. PowerShell の実行結果でエラーが出た場合（例: 実行ポリシー制限）、`:messages` に `[ime-auto] Windows IME toggle failed: ...` の通知が出ることを確認

**既知の制限**:

- IME の状態確認は `Get-WinUserLanguageList` の `InputMethodTips` に `0411:00000411`（Microsoft IME）が含まれるかで判定しており、他社製 IME（Google 日本語入力など）を使用している場合は状態判定に失敗する可能性があります
- 状態が判定できない場合（PowerShell 実行エラーなど）は、意図しない状態にトグルしてしまうことを避けるため、切り替え自体をスキップし警告を通知します
- IME の切り替えには `{KANJI}`（変換キー相当）を送信する `SendKeys` を使用しています。フォーカスが Neovim のウィンドウにない場合など、キー送信が期待通りに機能しない環境がある可能性があります
- 実機 Windows 環境でのテストは実施できていないため、上記の手順で動作確認の上、問題があれば Issue で報告してください

## 🤝 CONTRIBUTING

Issue 報告や Pull Request を歓迎します！

開発に関する詳細：
- 📖 [CONTRIBUTING.md](CONTRIBUTING.md) - 貢献ガイド
- 📖 [CLAUDE.md](CLAUDE.md) - 開発ガイド（アーキテクチャ、実装詳細）

## 📄 LICENSE

MIT License

