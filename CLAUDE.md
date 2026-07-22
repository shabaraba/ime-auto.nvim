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

// 4. 失敗時は警告を出力
fputs("Warning: IME switch incomplete...", stderr)
return false
```

**入力モード強制（JISキーボード専用、v1.x.x以降）**:
Carbon APIは**Input Source ID**（例: `com.google.inputmethod.Japanese.base`）を切り替えるが、
その中の**入力モード**（ひらがな/英数）は切り替えられない。この問題に対処するため：

```swift
// JISキーボードでのみ実行
if isJISKeyboard() {
    if isJapaneseIME(targetID) {
        sendKanaKey()  // かなキー（0x68）を送信してひらがなモードに
    } else if isEnglishIME(targetID) {
        sendEisuKey()  // 英数キー（0x66）を送信して英数モードに
    }
}
```

**キーボードタイプ別の動作**:
- **JISキーボード** (type 40, 41): Input Source切り替え + 入力モード強制
- **USキーボード** (type 42, 43, その他): Input Source切り替えのみ（入力モード強制は不要）

**パフォーマンス**:
- 通常ケース: 50ms（1回の待機で完了）
- 最悪ケース: 200ms（3回リトライ後に完了）
- JISキーボード: +30ms（キーイベント送信）
- 体感への影響: ほぼなし（人間の反応時間は200ms以上）

### 5. モード別 TISInputSource ID 直接選択の調査（Issue #36・設計判断記録）

**背景**: 現行実装（Input Source 切替＋JISキーボード判定＋かな/英数キー合成送信＋アクセシビリティ権限）は特殊対応の積み重ねである。多くの日本語IMEはモードごとに個別の `TISInputSource` ID（例: `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese` vs `...Roman`）を公開しているため、それを `TISSelectInputSource` で直接選択できればキー送信・キーボード判定・権限依存を排除できるのではないか、という仮説を検証した。

**調査方法**: 開発機（Apple Silicon Mac / macOS 26 / Swift 6.2）上で `swift-ime list`（`TISCreateInputSourceList(nil, false/true)`）を実行し、実際にインストールされている日本語IME（Kotoeri、Google日本語入力、azooKey）のモード別IDを列挙。その上で、各モード別IDに対して直接 `TISSelectInputSource` を呼び、`TISCopyCurrentKeyboardInputSource` で実際に切り替わるかを検証するPoCツールを作成し実行した。検証後は変更したシステムの入力ソース有効化状態を元に戻した。

**検証結果**:

| IME | モード別ID | 列挙可否 (`includeAllInstalled: true`) | `TISSelectInputSource` の結果 |
|---|---|---|---|
| Kotoeri（Apple標準・ローマ字入力） | `...Kotoeri.RomajiTyping.Japanese` / `...Roman` | 列挙可 | 親メソッド（`...RomajiTyping`）を `TISEnableInputSource` で有効化した状態でのみ **成功（OSStatus 0）**。切替後 `TISCopyCurrentKeyboardInputSource` は要求したモード別IDを正しく返した |
| Google日本語入力 | `com.google.inputmethod.Japanese.Roman` / `.Katakana` / `.HalfWidthKana` / `.FullWidthRoman` | 列挙可（`selectCapable=true` と自己申告） | **失敗（OSStatus -50 = paramErr）**。IME自体が現在有効かつアクティブでも、ベースID（`.base` = ひらがな）以外のモード別IDは選択不可。列挙上は "選択可能" と見えるが実体は情報提供用のダミーエントリで、実際のモード切替はIME内部の非公開機構（メニュー選択やキー入力相当の内部イベント）に依存している |

**結論・設計判断: 移行しない（現行のキー送信方式を維持）**

理由:
1. **Google日本語入力で完全に失敗する**: モード別IDが列挙されても `TISSelectInputSource` が `paramErr` を返し、選択不可であることを実機で確認した。Google日本語入力は本プラグインの主要ユーザー層が使う代表的な日本語IMEであり、ここで機能しない時点で「キー送信・JIS判定・権限依存を一括で解消する」というIssueの狙いは達成できない。
2. **Kotoeriでの成功は「ID読み戻り」レベルの検証に留まる**: `TISSelectInputSource` 後に `TISCopyCurrentKeyboardInputSource` が要求IDと一致することは確認できたが、これは既存不具合（「メニューバーは日本語だが英字しか打てない」＝ID表示と実際の変換モードが乖離する問題）そのものを検知できる指標ではない。実際のキー入力結果（ひらがな変換が有効かどうか）まではヘッドレス環境で確定検証できておらず、Kotoeriについても本当に不具合が解消するとまでは断言できない。
3. **ハイブリッド化のコストに見合わない**: 仮にKotoeriのみモード別ID直接選択に切り替えても、Google日本語入力や未検証のATOK等のためにキー送信＋JIS判定＋アクセシビリティ権限のフォールバック経路は結局維持する必要がある。ベンダーごとに異なる非公式なID命名規則（`.RomajiTyping.Japanese`/`.Roman` 等）に依存したヒューリスティックを追加することは、将来のmacOS/IMEアップデートで壊れるリスクを増やす一方、ユーザー体験上の恩恵（権限不要・キー送信不要）を全ユーザーには提供できない。
4. 以上より、キーボードタイプ判定＋かな/英数キー合成送信によるモード強制ロジック（本ファイル「入力モード強制（JISキーボード専用）」節）は現状維持とする。将来的に主要IME側がモード別ID選択を公式にサポートする、または実際のキー入力結果までヘッドレスに検証できる手段が確立された場合は、本調査を再検討する。



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
