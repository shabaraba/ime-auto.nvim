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
- **macOS**: JIS キーボードで入力モード（ひらがな/英数）を強制切り替えする機能を使うには、アクセシビリティ権限が必要です（システム設定 > プライバシーとセキュリティ > アクセシビリティ で Neovim/ターミナルアプリを許可）

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

## 🐧 Linux 対応

Linux では [fcitx](https://fcitx-im.org/) と [IBus](https://github.com/ibus/ibus) をサポートしています（`fcitx-remote` が優先、なければ `ibus` を使用）。

- インストール不要・設定不要で自動検出されます
- macOS と同じスロット方式で Insert/Normal モードごとの IME 状態を記憶します
- 状態は `~/.local/share/nvim/ime-auto/saved-ime-{a,b}.txt` に保存されます（パーミッション 0600、ディレクトリ 0700）

必要なコマンド:
```bash
# fcitx の場合
which fcitx-remote

# ibus の場合
which ibus
```

### 🪟 Windows サポート（実験的）

Windows では PowerShell スクリプト（`powershell/ime-tool.ps1`）を使って IME を制御します。追加のインストール作業は不要です（`ExecutionPolicy Bypass` で実行されます）。

- macOS と同様の Slot A/B 方式で、Insert/Normal モードそれぞれの IME 状態を記憶します
  - Slot A: Insert モードの IME 状態
  - Slot B: Normal モードの IME 状態
  - 保存先: `%LOCALAPPDATA%\nvim-data\ime-auto\saved-ime-{a,b}.txt`（現在のユーザーのみアクセス可能な ACL を設定）
- 現在の IME 取得には `Get-WinUserLanguageList` の `InputMethodTips` を使用します
- IME 切り替えは `Set-WinUserLanguageList` で対象の `InputMethodTip` を先頭に並べ替えることで実現しています

**既知の制限（Phase 1 実装）**:
- `Set-WinUserLanguageList` によるユーザー既定入力方式の切り替えは、Windows の言語バーがフォーカス中のウィンドウへ反映するタイミングに依存するため、macOS の Carbon API 実装ほど即時性・確実性が高くありません
- 特定の IME（Google 日本語入力など）が持つ「ひらがな/英数」等の入力モードそのものまでは制御できません。あくまで登録されている `InputMethodTip`（入力方式）の切り替えのみです
- より高精度な制御には Win32 API（`ITfInputProcessorProfiles` や `WM_INPUTLANGCHANGEREQUEST` 等）との連携が必要ですが、これは今後のフェーズで検討します
- 動作確認は限定的です。問題があれば [Issues](https://github.com/shabaraba/ime-auto.nvim/issues) で報告してください

## 🔧 トラブルシューティング

### エスケープシーケンスが動作しない

- ✅ 全角文字 `ｋｊ` で入力していることを確認
- ✅ 入力を確定（エンター）してください

### メニューバーは日本語なのに英字しか打てない（JIS キーボード）

- ✅ アクセシビリティ権限が付与されているか確認してください（システム設定 > プライバシーとセキュリティ > アクセシビリティ）
- 権限がない場合、キー送信は OS に黙って破棄されるため、`~/.local/share/nvim/ime-auto/debug.log`（デバッグモード有効時）や標準エラー出力に警告が記録されます

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

