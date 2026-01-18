# CLAUDE.md - ime-auto.nvim 開発ガイド

このファイルは、Claude Code や vibing.nvim を使って ime-auto.nvim を開発する際の指針とプロジェクト固有のルールを定義します。

## プロジェクト概要

**ime-auto.nvim** は、Neovim で日本語入力時の IME（Input Method Editor）を自動制御するプラグインです。

### 主要機能

1. **エスケープシーケンス機能** - 全角文字でのモード切り替え
2. **IME 自動切り替え** - モード遷移時の IME 制御
3. **スロットベース状態管理** - Insert/Normal モードの IME 状態を永続化
4. **Swift ツール統合（macOS）** - Carbon API による高速 IME 制御
5. **クロスプラットフォーム対応** - macOS/Windows/Linux サポート

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
├── tests/
│   ├── priority-1/           # 単体テスト（Plenary.nvim）
│   └── e2e/                  # E2Eテスト（vibing.nvim使用）
└── plugin/
    └── ime-auto.lua          # プラグイン初期化
```

### 依存関係フロー

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

## 開発ルール

### コーディング規約

1. **ファイルサイズ**: 1ファイル100行程度を目標（最大200行）
2. **モジュール分割**: 単一責任の原則に従う
3. **コメント**: 不要なコメントは残さない（コードは自己文書化）
4. **命名規則**:
   - 変数・関数: `snake_case`
   - モジュール: `M` テーブルを使用
   - プライベート関数: モジュール外で使わない関数は local にする

### テスト要件

すべての変更は以下のテストをパスする必要があります：

**単体テスト（必須）**:
```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }" \
  -c "qa!"
```

**E2Eテスト（推奨）**:
```vim
:source tests/e2e/vibing_execution_script.lua
```

### パフォーマンス要件

1. **キャッシング**: 頻繁に呼ばれる関数は結果をキャッシュ（TTL: 500ms）
2. **デバウンス**: 連続するイベントは100msデバウンス
3. **遅延初期化**: コンパイル・読み込みは初回実行時のみ

### セキュリティ要件

1. **入力検証**: すべての外部入力を正規表現で検証
   - IME ID: `^[%w%.%-_]+$`
   - スロット名: `^[a-zA-Z0-9_-]+$`
2. **パーミッション**: ファイルは 0600、ディレクトリは 0700
3. **Path Traversal 防止**: パス操作前に必ず検証

## 主要機能の実装詳細

### 1. エスケープシーケンス機能

**ファイル**: `lua/ime-auto/escape.lua`

**実装フロー**:
```
1. InsertCharPre イベント → on_insert_char_pre() 呼び出し
2. 1文字目判定 → pending_char に保存、タイマー開始
3. 2文字目判定（escape_timeout 内）
   ├─ YES → バッファから削除、normalモードへ移行
   └─ NO → タイムアウトでリセット
```

**エッジケース**:
- マルチバイト文字境界の処理（`vim.fn.strchars()` 使用）
- タイマーのクリーンアップ
- バッファが変更された場合のリセット

### 2. IME 自動切り替え

**ファイル**: `lua/ime-auto/ime.lua`

**最適化**:
- **IME状態キャッシュ**: `cached_ime_state` テーブル（TTL: 500ms）
- **デバウンス**: `debounce_timer` で100msデバウンス

**プラットフォーム別実装**:
- macOS: `swift-ime-tool.lua` 経由で Swift ツール呼び出し
- Windows: PowerShell スクリプト実行
- Linux: `fcitx-remote` または `ibus` コマンド実行

### 3. スロットベース状態管理

**ファイル**: `swift/ime-tool.swift`

**スロット設計**:
- Slot A: Insert モードの IME 状態
- Slot B: Normal モードの IME 状態
- ストレージ: `~/.local/share/nvim/ime-auto/saved-ime-{a|b}.txt`

**主要関数**:
- `toggle_from_insert()`: Insert → Normal 遷移時
- `toggle_from_normal()`: Normal → Insert 遷移時
- `writeToSlot()`: スロットに IME ID を保存
- `readFromSlot()`: スロットから IME ID を読み込み

### 4. Swift ツール統合

**ファイル**: `lua/ime-auto/swift-ime-tool.lua`

**コンパイルフロー**:
```
1. ensure_compiled() 呼び出し
2. バイナリ存在チェック → mtime 比較
3. Swift ソース読み込み → コピー
4. swiftc コンパイル実行
```

**遅延コンパイル**:
- 初回実行時のみコンパイル
- mtime ベースで自動リコンパイル判定
- エラー時は詳細なメッセージを表示

## 開発ワークフロー

### 新機能開発時

1. **設計確認**:
   - 既存のアーキテクチャに適合するか検討
   - 単一責任の原則に従っているか確認
   - パフォーマンスへの影響を評価

2. **実装**:
   - 該当モジュールを編集
   - 100行以内に収まるよう設計
   - エッジケースを考慮

3. **テスト**:
   - 単体テストを追加（`tests/priority-1/`）
   - E2Eテストシナリオを確認
   - すべてのテストをパス

4. **ドキュメント更新**:
   - README.md に機能を追加
   - CLAUDE.md に実装詳細を追記

### バグ修正時

1. **再現**:
   - バグを再現する最小限のテストケースを作成
   - デバッグモードで動作を確認

2. **修正**:
   - 根本原因を特定
   - 最小限の変更で修正
   - 他への影響を確認

3. **テスト**:
   - バグを再現するテストを追加
   - すべてのテストをパス

### リファクタリング時

1. **テスト準備**:
   - 既存機能を保証するテストがあることを確認
   - なければテストを追加

2. **段階的リファクタリング**:
   - 一度に大きく変更しない
   - 各ステップでテストをパス

3. **最終確認**:
   - すべてのテストをパス
   - パフォーマンスが低下していないか確認

## トラブルシューティング

### デバッグ方法

1. **デバッグモードを有効化**:
   ```lua
   require("ime-auto").setup({ debug = true })
   ```

2. **ログ確認**:
   - `:messages` でログを確認
   - `vim.notify()` でデバッグ出力

3. **Swift ツールのデバッグ**:
   ```bash
   # Swift ツールを直接実行
   ~/.local/share/nvim/ime-auto/swift-ime
   ~/.local/share/nvim/ime-auto/swift-ime list
   ```

### よくある問題

**問題**: Swift コンパイルに失敗する
**解決**: Xcode Command Line Tools をインストール
```bash
xcode-select --install
swiftc --version
```

**問題**: IME が切り替わらない
**解決**:
1. OS 設定を明示的に指定
2. カスタムコマンドを使用
3. デバッグモードで動作を確認

**問題**: エスケープシーケンスが動作しない
**解決**:
1. 全角文字で入力していることを確認
2. タイムアウトを長めに設定
3. マルチバイト文字境界の問題を確認

## Claude Code / vibing.nvim での開発

### vibing.nvim を使った開発フロー

1. **ブランチ作成**:
   ```vim
   :VibingChatWorktree feature-name
   ```

2. **コード変更**:
   - vibing.nvim で AI に実装を依頼
   - 自動的にテストを実行

3. **テスト確認**:
   ```vim
   :source tests/e2e/vibing_execution_script.lua
   ```

4. **コミット**:
   - AI に依頼してコミットメッセージを生成
   - PR を作成

### Claude Code での質問例

**実装に関する質問**:
- 「エスケープシーケンス機能の実装を説明して」
- 「IME 状態キャッシュの仕組みを教えて」
- 「Swift ツールのセキュリティ対策について」

**新機能の追加**:
- 「Linux で fcitx5 をサポートしたい」
- 「エスケープシーケンスを3文字に対応させたい」
- 「IME 切り替え時のアニメーションを追加したい」

**バグ修正**:
- 「高速にモード切り替えすると IME が切り替わらない」
- 「マルチバイト文字でエスケープシーケンスが動作しない」
- 「Windows で PowerShell エラーが出る」

## コミット規約

**コミットメッセージ**: 英語で Semantic Commit Messages を使用

```
feat: Add support for fcitx5 on Linux
fix: Handle multibyte character boundaries correctly
docs: Update README with architecture section
style: Format Swift code with swiftformat
refactor: Extract IME control logic to separate module
test: Add tests for escape sequence timeout
chore: Update dependencies
```

**コミット時の注意**:
- 1コミット = 1つの論理的な変更
- テストをパスしてからコミット
- 関連する issue がある場合は `fixes #123` を含める

## リリースプロセス

1. **バージョン決定**: Semantic Versioning に従う
   - MAJOR: 破壊的変更
   - MINOR: 新機能追加
   - PATCH: バグ修正

2. **CHANGELOG 更新**: 変更内容を記載

3. **タグ作成**:
   ```bash
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   ```

## 参考リソース

- **README.md**: ユーザー向けドキュメント
- **tests/e2e/MANUAL_TEST_GUIDE.md**: 手動テストガイド
- **tests/e2e/VIBING_EXECUTION_GUIDE.md**: vibing.nvim 実行ガイド
- **Carbon API ドキュメント**: [Apple Developer Documentation](https://developer.apple.com/documentation/coreservices/carbon_core)

## ライセンス

MIT License - 詳細は LICENSE ファイルを参照
