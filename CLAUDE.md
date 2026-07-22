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
│   ├── ime.lua               # IME制御コアロジック（キャッシング・非同期実行・状態管理）
│   ├── ime-platform.lua      # OS別IME制御コマンド実行（macOS/Windows/Linux）
│   ├── escape.lua            # エスケープシーケンス実装（InsertCharPre）
│   ├── swift-ime-tool.lua    # Swift統合レイヤー（プリコンパイル済みバイナリ利用）
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
 ├─ ime.lua (IME制御・状態管理)
 │   └─ ime-platform.lua (OS別コマンド実行)
 │       ├─ swift-ime-tool.lua (macOS Swift統合)
 │       │   └─ swift/ime-tool.swift (Carbon API)
 │       ├─ PowerShell (Windows)
 │       └─ fcitx-remote/ibus (Linux)
 ├─ escape.lua (エスケープシーケンス)
 └─ utils.lua (ユーティリティ)
```

## 開発ルール

### コーディング規約

1. **ファイルサイズ**: 1ファイル100行程度を目標（最大200行）
   - 例外: `swift/ime-tool.swift` はCLI引数ごとのコマンド分岐（`list`/`toggle-from-insert`/`toggle-from-normal`/`toggle`/`save-insert`/`save-normal`）とCarbon APIによる同期待機・リトライ・JISキーボード対応ロジックが密接に絡み合っており、無理に分割するとCarbon API呼び出しの順序保証（`TISSelectInputSource`の非同期待機→検証→リトライ→入力モード強制）が追いにくくなるため、単一ファイルのまま保守する
2. **モジュール分割**: 単一責任の原則に従う
   - 例: `ime.lua`（IME状態のキャッシュ・デバウンス・保存/復元ロジック）と `ime-platform.lua`（macOS/Windows/LinuxごとのIME切り替えコマンド実行）は責務ごとに分離している
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
2. **非同期実行**: InsertEnter/InsertLeave での IME 切り替えは `vim.system()` による非同期呼び出しでメインループをブロックしない
3. **遅延初期化**: プリコンパイル済みバイナリ（`bin/swift-ime`）のパス解決は初回実行時のみ行いキャッシュする

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

**ファイル**: `lua/ime-auto/ime.lua`（状態管理）、`lua/ime-auto/ime-platform.lua`（OS別コマンド実行）

**最適化**:
- **IME状態キャッシュ**: `ime_state_cache` テーブル（TTL: 500ms）
- **非同期IME切り替え**: `swift-ime-tool.lua` が `vim.system()` を使い、InsertEnter/InsertLeave の Swift バイナリ呼び出しをメインループ非ブロッキングで実行

**プラットフォーム別実装**（`ime-platform.lua`）:
- macOS: `M.macos()` から `swift-ime-tool.lua` 経由で Swift ツール呼び出し
- Windows: `M.windows()` から `windows-ime-tool.lua` 経由で PowerShell スクリプト実行
- Linux: `M.linux()` から `linux-ime-tool.lua` 経由で `fcitx-remote` または `ibus` コマンド実行

**Windows実装の詳細**: `windows-ime-tool.lua` と `powershell/ime-tool.ps1` を参照（Slot A/B方式、macOSと同様の設計）。

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

**バイナリ解決フロー（プリコンパイル済みUniversal Binary、v0.1.x以降）**:
```
1. ensure_compiled() 呼び出し
2. 既に解決済みパスが存在しファイル読み取り可能なら即 true を返す
3. プラグインルート配下の bin/swift-ime（事前ビルド済みUniversal Binary）を探索
   → 見つかれば swift_bin_path にキャッシュして true を返す
4. 見つからない場合は false とエラーメッセージ（再インストール手順・
   ./scripts/build-universal-binary.sh の案内・issue報告先）を返す
```

**注意**: 現行実装は `swiftc` を一切呼び出さない。Swift ツールはリリース時に
`scripts/build-universal-binary.sh` で事前ビルドされ `bin/swift-ime` としてプラグインに
同梱される。実行時はこのバイナリの存在確認のみを行う（旧来のmtimeベース遅延コンパイル方式は廃止済み）。

**IME切り替えの同期処理（v1.x.x以降）**:
Carbon APIの`TISSelectInputSource()`は非同期のため、以下の対策を実装:

```swift
// switchToInputSource() の実装
TISSelectInputSource(source)

// 1. 初回待機（50ms）
usleep(50000)

// 2. 切り替え完了を検証
if getCurrentInputSourceID() == targetID {
    return true  // 成功
}

// 3. リトライ（最大3回、各50ms）
for _ in 0..<3 {
    usleep(50000)
    if getCurrentInputSourceID() == targetID {
        return true
    }
}

// 4. 失敗時は詳細ログを出力（debugLog経由でstderr、IME_AUTO_DEBUG=1時はログファイルにも出力）
debugLog("[switchToInputSource] FAILED after all retries (target: \(targetID), current: \(currentID))")
return false
```

**入力モード強制（JISキーボード専用、v1.x.x以降）**:
Carbon APIは**Input Source ID**（例: `com.google.inputmethod.Japanese.base`）を切り替えるが、
その中の**入力モード**（ひらがな/英数）は切り替えられない。この問題に対処するため：

```swift
// JISキーボードでのみ実行
// isASCIICapable() は kTISPropertyInputSourceIsASCIICapable を参照する
// （IDの部分文字列マッチではなく、TISの正式プロパティで判定）
if isJISKeyboard() {
    if isASCIICapable(source) {
        sendEisuKey()  // 英数キー（0x66）を送信して英数モードに
    } else {
        sendKanaKey()  // かなキー（0x68）を送信してひらがなモードに
    }
}
```

**IMEステータス判定（`:ImeAutoStatus` 等、v1.x.x以降）**:
Lua側 (`ime.lua`) はID文字列のマッチングでIME状態を再判定せず、Swiftツールの `status` コマンドが返す
`on`/`off`（`isCurrentSourceASCIICapable()` によるTISプロパティベースの判定結果）をそのまま信頼する。

**キーボードタイプ別の動作**:
- **JISキーボード** (type 40, 41): Input Source切り替え + 入力モード強制
- **USキーボード** (type 42, 43, その他): Input Source切り替えのみ（入力モード強制は不要）

**アクセシビリティ権限（macOS必須）**:
`sendKanaKey()`/`sendEisuKey()` が送信する `CGEvent` は、Neovim（またはターミナルアプリ）に
アクセシビリティ権限が付与されていないと OS に黙って破棄される。Input Source ID の切り替え自体は
成功するため、権限がない環境では失敗が握りつぶされ「メニューバーは日本語なのに英字しか打てない」
問題が再発する。この問題を検知できるよう、キー送信前に `AXIsProcessTrusted()` を確認し、
権限がない場合はキー送信をスキップして stderr（および `debug.log`）に警告を出力する：

```swift
func checkAccessibilityPermission() -> Bool {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        debugLog("Warning: Accessibility permission not granted. ...")
    }
    return trusted
}
```

権限は システム設定 > プライバシーとセキュリティ > アクセシビリティ で
Neovim/ターミナルアプリを許可することで付与できる。

**パフォーマンス**:
- 通常ケース: 50ms（1回の待機で完了）
- 最悪ケース: 200ms（初回50ms + リトライ3回×50ms）
- JISキーボード: +60ms（`sendKanaKey`/`sendEisuKey` は各 `usleep(10000)`（キー押下後10ms）+ `usleep(50000)`（キー解放後50ms、入力モード安定待ち）で構成）
- 体感への影響: ほぼなし（人間の反応時間は200ms以上）
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

**問題**: `bin/swift-ime` が見つからない（`ensure_compiled()` がエラーを返す）
**原因**: 通常配布物には `bin/swift-ime`（プリコンパイル済みUniversal Binary）が同梱されているため
発生しない想定だが、開発用チェックアウトやビルド漏れの場合に発生しうる
**解決**: `./scripts/build-universal-binary.sh` を実行してバイナリを再生成する
（内部で `swiftc` を使用するため、事前に Xcode Command Line Tools が必要）
```bash
xcode-select --install
swiftc --version
./scripts/build-universal-binary.sh
```

**問題**: IME が切り替わらない
**解決**:
1. OS 設定を明示的に指定
2. カスタムコマンドを使用
3. デバッグモードで動作を確認

**問題**: IME 状態が不一致（メニューバーは日本語だが英字しか打てない）
**原因**: Carbon APIの制限により、Input Source IDは切り替わるが、その中の入力モード（ひらがな/英数）が切り替わらない
**解決済み**: v1.x.x 以降、以下の対策を実装済み
1. Swift側で50msの待機とリトライロジック（最大3回） - Input Source ID切り替えの完了を保証
2. JISキーボード検出により、必要な場合のみ入力モードを強制切り替え
   - JISキーボード: `英数`/`かな`キーを送信して入力モードを強制
   - USキーボード: 入力モード強制は不要（自動的に正しいモードになる）
3. 切り替え失敗時は警告を stderr に出力
**対処法**:
- 最新版（v1.x.x以降）では自動で解決されます
- JISキーボードの場合のみキーイベント送信により入力モードを強制
- 問題が続く場合は、デバッグログ（`~/.local/share/nvim/ime-auto/debug.log`）を確認してください

**問題**: USキーボードなのにモード切替時にフォーカス中の別アプリへキーが誤入力される（#14）
**原因**: `isJISKeyboard()`が`LMGetKbdType()`の未知の戻り値をすべてJISとみなすフォールバックになっており、
USキーボードでも「かな」「英数」キー（存在しない仮想キーコード）のCGEventが誤送出されていた
**解決済み**: `KBGetLayoutType(LMGetKbdType())`でCarbon APIが返す物理レイアウト種別
（`kKeyboardJIS`/`kKeyboardANSI`/`kKeyboardISO`）を直接判定するよう変更。
判定不能な場合のデフォルトも「JISとみなす」から「JISとみなさない」に変更した。
Kotoeri（日本語IME）のID一致判定も、現行macOSのID命名（`RomajiTyping`/`KanaTyping`等）の
前方一致に対応させたが、これはCarbon APIで判定できない場合の最終フォールバックに過ぎない。
**手動確認方法**:
```bash
# swift-ime バイナリで実機のキーボードレイアウト判定結果を確認できる
~/.local/share/nvim/ime-auto/swift-ime keyboard-info
# 出力例: kbdType=93 layoutType=1246319392 isJISKeyboard=true
```
USキーボードでは `isJISKeyboard=false` となり、モード切替時にキーイベントが送出されないことを確認する。

**問題**: JISキーボードで入力モードが強制切り替えされない（同上の症状が権限起因で再発する）
**原因**: `sendKanaKey`/`sendEisuKey` が送信する CGEvent は、Neovim（またはターミナルアプリ）にアクセシビリティ権限が付与されていないと OS に黙って破棄される。Input Source ID の切り替え自体は成功しているため `switchToInputSource` は `true`/exit 0 を返し、失敗が握りつぶされる
**解決済み**: `sendKanaKey`/`sendEisuKey` の実行前に `AXIsProcessTrusted()` を確認し、権限がない場合はキー送信をスキップして stderr（および `debug.log`）に警告を出力するようにした
**対処法**:
1. システム設定 > プライバシーとセキュリティ > アクセシビリティ で Neovim/ターミナルアプリを許可
2. 権限変更後は Neovim（または Swift ツールを起動しているプロセス）を再起動
3. `~/.local/share/nvim/ime-auto/debug.log` に `Warning: Accessibility permission not granted...` が出力されていないか確認

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
