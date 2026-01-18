# ime-auto.nvim E2Eテストスイート - 完全ガイド

**作成日**: 2026-01-18
**テスト総数**: 12ケース
**対象プラグイン**: ime-auto.nvim
**テストフレームワーク**: plenary.nvim

---

## 📖 目次

1. [概要](#概要)
2. [テスト環境セットアップ](#テスト環境セットアップ)
3. [テスト実行方法](#テスト実行方法)
4. [テストケース一覧](#テストケース一覧)
5. [コードレビューで発見された問題](#コードレビューで発見された問題)
6. [実装ガイドライン](#実装ガイドライン)
7. [CI/CD統合](#cicd統合)

---

## 概要

このE2Eテストスイートは、ime-auto.nvimの包括的な品質保証を目的としています。

### テストの目的

- ✅ **機能の正確性**: コア機能が正しく動作することを保証
- ✅ **バグの早期発見**: コードレビューで特定された潜在的バグを検出
- ✅ **リグレッション防止**: 既存機能の破壊を防ぐ
- ✅ **OS互換性**: macOS, Windows, Linuxでの動作保証
- ✅ **ドキュメント**: テストケースが仕様書の役割を果たす

### テスト戦略

テストは3つの優先度に分類されています：

| 優先度 | ケース数 | 説明 | 実装必須度 |
|--------|---------|------|----------|
| **Priority 1: Critical** | 5 | コア機能・潜在的バグ | 必須 |
| **Priority 2: Important** | 4 | エッジケース・エラーハンドリング | 推奨 |
| **Priority 3: Normal** | 3 | OS固有・追加機能 | あると良い |

---

## テスト環境セットアップ

### 前提条件

```bash
# Neovim
nvim --version  # v0.9.0以降

# plenary.nvim（テストフレームワーク）
git clone https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim

# ime-auto.nvim
cd ~/workspace/nvim-plugins/ime-auto.nvim
```

### macOS固有の要件

```bash
# Swiftコンパイラ（macOSのみ）
swiftc --version

# 未インストールの場合
xcode-select --install
```

### Linux固有の要件

```bash
# fcitxまたはibus
which fcitx-remote  # または
which ibus
```

### テストディレクトリ構造

```
ime-auto.nvim/
├── lua/
│   └── ime-auto/
│       ├── init.lua
│       ├── ime.lua
│       ├── escape.lua
│       └── ...
├── tests/
│   ├── minimal_init.lua       # テスト用最小設定
│   ├── priority-1/            # Critical tests
│   │   ├── 01_basic_ime_switching_spec.lua
│   │   ├── 02_rapid_mode_switching_spec.lua
│   │   ├── 03_multibyte_char_boundaries_spec.lua
│   │   ├── 04_swift_tool_compilation_spec.lua
│   │   └── 05_ime_state_persistence_spec.lua
│   ├── priority-2/            # Important tests
│   │   ├── 06_resource_cleanup_spec.lua
│   │   ├── 07_config_validation_spec.lua
│   │   ├── 08_macos_slot_initialization_spec.lua
│   │   └── 09_ui_robustness_spec.lua
│   └── priority-3/            # Normal tests
│       ├── 10_os_specific_behavior_spec.lua
│       ├── 11_runtime_config_changes_spec.lua
│       └── 12_debug_mode_spec.lua
└── docs/
    └── e2e-tests/             # このドキュメント
```

### minimal_init.lua（サンプル）

```lua
-- tests/minimal_init.lua
vim.cmd([[set runtimepath+=.]])
vim.cmd([[set runtimepath+=~/.local/share/nvim/site/pack/vendor/start/plenary.nvim]])

-- ime-auto.nvimのロード
vim.opt.rtp:append(".")

-- テスト用の基本設定
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- plenary.nvimのロード
require("plenary.busted")
```

---

## テスト実行方法

### 全テスト実行

```bash
# すべてのテストを実行
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

### 優先度別実行

```bash
# Priority 1（Critical）のみ
nvim --headless -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }"

# Priority 2（Important）のみ
nvim --headless -c "PlenaryBustedDirectory tests/priority-2/ { minimal_init = 'tests/minimal_init.lua' }"

# Priority 3（Normal）のみ
nvim --headless -c "PlenaryBustedDirectory tests/priority-3/ { minimal_init = 'tests/minimal_init.lua' }"
```

### 個別テスト実行

```bash
# 特定のテストファイル
nvim --headless -c "PlenaryBustedFile tests/priority-1/01_basic_ime_switching_spec.lua { minimal_init = 'tests/minimal_init.lua' }"
```

### OS固有のテスト

```bash
# macOS専用テストのみ
nvim --headless -c "PlenaryBustedFile tests/priority-1/04_swift_tool_compilation_spec.lua { minimal_init = 'tests/minimal_init.lua' }"

nvim --headless -c "PlenaryBustedFile tests/priority-2/08_macos_slot_initialization_spec.lua { minimal_init = 'tests/minimal_init.lua' }"
```

### デバッグ実行

```bash
# デバッグモードで実行（詳細ログ）
nvim -c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'tests/minimal_init.lua' })"
```

---

## テストケース一覧

### Priority 1: Critical（必須）

#### [01: 基本的なIME切り替え](./priority-1-critical/01-basic-ime-switching.md)

**概要**: プラグインのコア機能を検証

**主な検証項目**:
- ✅ InsertEnter時のIME復元
- ✅ InsertLeave時のIME OFF
- ✅ エスケープシーケンス(`ｋｊ`)でのNormalモード移行
- ✅ エスケープシーケンスの文字削除精度

**重要度**: ★★★★★
**実装必須**: はい

---

#### [02: 高速モード切り替えでの競合状態](./priority-1-critical/02-rapid-mode-switching.md)

**概要**: キャッシュとデバウンスの協調動作を検証

**発見された潜在的バグ**:
- 高速なInsert→Normal→Insert切り替え時、キャッシュが古い状態を返す可能性（信頼度95%）

**主な検証項目**:
- ✅ デバウンス機構の基本動作
- ✅ 100ms以内のモード切り替えでの状態整合性
- ✅ キャッシュTTL（500ms）の動作
- ✅ システムコールの削減効果

**重要度**: ★★★★★
**実装必須**: はい

---

#### [03: マルチバイト文字境界の正確性](./priority-1-critical/03-multibyte-char-boundaries.md)

**概要**: UTF-8文字境界処理の正確性を検証

**発見された潜在的バグ**:
- `strpart()`（バイト単位）と`strcharpart()`（文字単位）の混在による境界計算エラー（信頼度90%）

**主な検証項目**:
- ✅ 全角日本語後のエスケープシーケンス
- ✅ 絵文字（4バイトUTF-8）後のエスケープシーケンス
- ✅ 混在文字列での境界保持
- ✅ 行頭でのエスケープシーケンス

**重要度**: ★★★★★
**実装必須**: はい

---

#### [04: Swiftツールのコンパイルとリカバリ](./priority-1-critical/04-swift-tool-compilation.md) (macOS専用)

**概要**: macOS Swiftツールの自動コンパイルとエラーハンドリングを検証

**発見された潜在的バグ**:
- コンパイル失敗時のリトライ機構なし（信頼度85%）
- バイナリ削除後の再コンパイル処理に不具合の可能性

**主な検証項目**:
- ✅ 初回コンパイル成功
- ✅ バイナリ削除後の自動再コンパイル
- ✅ コンパイルエラーのハンドリング
- ✅ 並行コンパイルの防止
- ✅ Swiftツールの実際の動作確認

**重要度**: ★★★★★（macOSユーザー向け）
**実装必須**: はい（macOS環境）

---

#### [05: IME状態の保存と復元](./priority-1-critical/05-ime-state-persistence.md)

**概要**: モード間でのIME状態管理を検証

**主な検証項目**:
- ✅ IME=ON状態の保存と復元
- ✅ IME=OFF状態の保存と復元
- ✅ 複数回のモード切り替えでの状態追跡
- ✅ macOSのslotベース管理
- ✅ 初回起動時の状態初期化
- ✅ 異なるバッファ間での状態独立性

**重要度**: ★★★★★
**実装必須**: はい

---

### Priority 2: Important（推奨）

#### [06: リソースクリーンアップ](./priority-2-important/06-resource-cleanup.md)

**概要**: タイマーとリソースの適切なクリーンアップを検証

**発見された潜在的バグ**:
- `:ImeAutoDisable`でタイマーを停止していない（信頼度85%）

**主な検証項目**:
- ✅ プラグイン無効化時のデバウンスタイマー停止
- ✅ エスケープシーケンスタイマーのクリーンアップ
- ✅ オートコマンドの削除
- ✅ 複数回の有効化/無効化サイクル
- ✅ Neovim終了時のクリーンアップ

**重要度**: ★★★★☆
**実装必須**: 推奨

---

#### [07: 設定バリデーション](./priority-2-important/07-config-validation.md)

**概要**: 無効な設定値のハンドリングを検証

**主な検証項目**:
- ✅ 無効な`escape_sequence`でのフォールバック
- ✅ 無効な`escape_timeout`でのフォールバック
- ✅ 型エラーのハンドリング
- ✅ カスタムコマンド未設定時の警告
- ✅ デバッグモードの動作

**重要度**: ★★★★☆
**実装必須**: 推奨

**改善提案**: バリデーションロジックと警告メッセージの追加

---

#### [08: macOS slot初期化](./priority-2-important/08-macos-slot-initialization.md) (macOS専用)

**概要**: macOSのslotベースIME管理システムの初期化を検証

**発見された潜在的バグ**:
- slot初期化時のロジック不整合（信頼度82%）
- Normalモードで別のIMEを使いたい場合に対応できない可能性

**主な検証項目**:
- ✅ 初回起動時のslot A/B初期化
- ✅ slot未存在時のフォールバック動作
- ✅ ユーザーがNormalモードで別のIMEを使う場合の対応
- ✅ restore_state()のmacOS専用ロジック
- ✅ slot ファイルの破損耐性
- ✅ パーミッション設定

**重要度**: ★★★★☆（macOSユーザー向け）
**実装必須**: 推奨（macOS環境）

**改善提案**: Normalモード用IMEの柔軟な設定オプション追加

---

#### [09: UIモジュールの堅牢性](./priority-2-important/09-ui-robustness.md)

**概要**: フローティングウィンドウUIの堅牢性を検証

**発見された潜在的バグ**:
- `getchar()`の無限ループリスク（信頼度80%）

**主な検証項目**:
- ✅ フローティングウィンドウの表示
- ✅ キー操作（j/k/Enter/ESC/q）
- ✅ 無効なキー入力の無視
- ✅ 空のリストでのエラーハンドリング
- ✅ 複数回のUI表示

**重要度**: ★★★☆☆
**実装必須**: 推奨

**改善提案**: getchar()のタイムアウト機構追加

---

### Priority 3: Normal（あると良い）

#### [10: OS別動作確認](./priority-3-normal/10-os-specific-behavior.md)

**概要**: 各OS固有のIME制御実装を検証

**主な検証項目**:
- ✅ OS自動検出の正確性
- ✅ macOS - Swift tool統合
- ✅ Windows - PowerShell統合
- ✅ Linux - fcitx優先、ibusフォールバック
- ✅ カスタムコマンドの動作
- ✅ OS間の一貫性

**重要度**: ★★★☆☆
**実装必須**: あると良い

---

#### [11: 設定変更の即時反映](./priority-3-normal/11-runtime-config-changes.md)

**概要**: 実行中の設定変更が即座に反映されることを検証

**主な検証項目**:
- ✅ `escape_sequence`の動的変更
- ✅ `escape_timeout`の動的変更
- ✅ `debug`モードの切り替え
- ✅ `custom_commands`の動的変更
- ✅ 複数設定の同時変更
- ✅ 既存状態への影響確認

**重要度**: ★★★☆☆
**実装必須**: あると良い

**改善提案**: 設定変更時の自動再初期化機構

---

#### [12: デバッグモード](./priority-3-normal/12-debug-mode.md)

**概要**: デバッグログ出力とトラブルシューティング支援を検証

**主な検証項目**:
- ✅ デバッグログの出力
- ✅ ログ内容の有用性
- ✅ ログ抑制（debug=false）
- ✅ `:ImeAutoStatus`コマンド
- ✅ エラー時のデバッグ情報
- ✅ ログフォーマット一貫性

**重要度**: ★★★☆☆
**実装必須**: あると良い

**改善提案**: タイミング情報と構造化ログの追加

---

## コードレビューで発見された問題

コードの詳細な分析により、以下の潜在的な問題が特定されました：

### Critical Issues（優先度高）

1. **競合状態: IMEキャッシュとデバウンス**
   - **ファイル**: `/lua/ime-auto/ime.lua` (L141-165, L172-193)
   - **問題**: 高速なモード切り替え時にキャッシュが古い状態を返す
   - **対応テスト**: [02: 高速モード切り替えでの競合状態](./priority-1-critical/02-rapid-mode-switching.md)
   - **信頼度**: 95%

2. **文字境界問題: マルチバイト文字処理**
   - **ファイル**: `/lua/ime-auto/escape.lua` (L20-44)
   - **問題**: `strpart()`と`strcharpart()`の混在による境界計算エラー
   - **対応テスト**: [03: マルチバイト文字境界の正確性](./priority-1-critical/03-multibyte-char-boundaries.md)
   - **信頼度**: 90%

3. **Swiftコンパイル失敗: リトライなし**
   - **ファイル**: `/lua/ime-auto/swift-ime-tool.lua` (L90-146)
   - **問題**: 一時的なエラーで永続的に失敗
   - **対応テスト**: [04: Swiftツールのコンパイルとリカバリ](./priority-1-critical/04-swift-tool-compilation.md)
   - **信頼度**: 85%

4. **restore_state()の意味的不整合 (macOS)**
   - **ファイル**: `/lua/ime-auto/ime.lua` (L199-216)
   - **問題**: 常にIME ONにする動作がユーザー意図と不一致の可能性
   - **対応テスト**: [08: macOS slot初期化](./priority-2-important/08-macos-slot-initialization.md)
   - **信頼度**: 90%

### Important Issues（優先度中）

5. **タイマークリーンアップ漏れ**
   - **ファイル**: `/lua/ime-auto/ime.lua` (L28-30, L141-165)
   - **問題**: プラグイン無効化時にタイマーが停止されない
   - **対応テスト**: [06: リソースクリーンアップ](./priority-2-important/06-resource-cleanup.md)
   - **信頼度**: 85%

6. **無限ループリスク: UIモジュール**
   - **ファイル**: `/lua/ime-auto/ui.lua` (L140-166)
   - **問題**: `getchar()`のタイムアウト機構なし
   - **対応テスト**: [09: UIモジュールの堅牢性](./priority-2-important/09-ui-robustness.md)
   - **信頼度**: 80%

7. **slot初期化の問題 (macOS)**
   - **ファイル**: `/swift/ime-tool.swift` (L105-128, L130-155)
   - **問題**: 初回起動時にslot BにABCがロックされる
   - **対応テスト**: [08: macOS slot初期化](./priority-2-important/08-macos-slot-initialization.md)
   - **信頼度**: 82%

---

## 実装ガイドライン

### テストファイルの命名規則

```
{番号}_{機能名}_spec.lua
```

例: `01_basic_ime_switching_spec.lua`

### テストの構造

```lua
-- tests/priority-1/01_basic_ime_switching_spec.lua
local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 01: Basic IME switching", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("1.1: InsertEnter時のIME復元", function()
    it("should restore IME state on InsertEnter", function()
      vim.cmd("startinsert")
      local initial_state = ime.get_status()
      vim.cmd("stopinsert")
      vim.wait(50)

      vim.cmd("startinsert")
      vim.wait(50)
      local restored_state = ime.get_status()

      assert.equals(initial_state, restored_state)

      vim.cmd("stopinsert")
    end)
  end)

  -- 他のテストケース...
end)
```

### アサーション一覧

```lua
-- 基本アサーション
assert.equals(expected, actual)
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)

-- 文字列
assert.matches(pattern, str)

-- テーブル
assert.same(expected_table, actual_table)

-- 条件スキップ
if condition then
  pending("Reason for skipping")
  return
end
```

### OS固有のテスト

```lua
describe("Test: macOS specific", function()
  before_each(function()
    if vim.fn.has("mac") == 0 then
      pending("This test is macOS only")
      return
    end
  end)

  it("should work on macOS", function()
    -- テストコード
  end)
end)
```

### モックとスパイ

```lua
-- vim.notifyのモック
local notifications = {}
local original_notify = vim.notify
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
  original_notify(msg, level)
end

-- テスト実行

-- クリーンアップ
vim.notify = original_notify

-- システムコールのスパイ
local call_count = 0
local original_control = ime.control
ime.control = function(action)
  if action == "off" then call_count = call_count + 1 end
  return original_control(action)
end

-- クリーンアップ
ime.control = original_control
```

---

## CI/CD統合

### GitHub Actions設定例

```yaml
# .github/workflows/test.yml
name: E2E Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        nvim-version: ['stable', 'nightly']

    steps:
      - uses: actions/checkout@v3

      - name: Setup Neovim
        uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.nvim-version }}

      - name: Install plenary.nvim
        run: |
          git clone https://github.com/nvim-lua/plenary.nvim \
            ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim

      - name: Install Xcode Command Line Tools (macOS)
        if: runner.os == 'macOS'
        run: |
          xcode-select --install || true
          swiftc --version

      - name: Run Priority 1 Tests (Critical)
        run: |
          nvim --headless -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }"

      - name: Run Priority 2 Tests (Important)
        run: |
          nvim --headless -c "PlenaryBustedDirectory tests/priority-2/ { minimal_init = 'tests/minimal_init.lua' }"

      - name: Run Priority 3 Tests (Normal)
        continue-on-error: true
        run: |
          nvim --headless -c "PlenaryBustedDirectory tests/priority-3/ { minimal_init = 'tests/minimal_init.lua' }"
```

### カバレッジ測定（オプション）

```yaml
      - name: Generate Coverage Report
        run: |
          nvim --headless -c "lua require('plenary.busted').run({ coverage = true })"

      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.out
```

---

## 次のステップ

### 1. テスト実装の優先順位

1. ✅ **Priority 1を完全実装**（必須）
   - 01: 基本的なIME切り替え
   - 02: 高速モード切り替えでの競合状態
   - 03: マルチバイト文字境界の正確性
   - 04: Swiftツールのコンパイルとリカバリ（macOS）
   - 05: IME状態の保存と復元

2. ⏳ **Priority 2を段階的に実装**（推奨）
   - 06: リソースクリーンアップ
   - 07: 設定バリデーション
   - 08: macOS slot初期化
   - 09: UIモジュールの堅牢性

3. ⏳ **Priority 3を必要に応じて実装**（あると良い）
   - 10: OS別動作確認
   - 11: 設定変更の即時反映
   - 12: デバッグモード

### 2. コード改善の実施

テストケースドキュメントに記載された「改善提案」を実装：

- **タイマークリーンアップ処理の追加** (06)
- **バリデーションロジックと警告メッセージ** (07)
- **Normalモード用IMEの柔軟な設定** (08)
- **getchar()のタイムアウト機構** (09)
- **設定変更時の自動再初期化** (11)
- **タイミング情報と構造化ログ** (12)

### 3. CI/CD統合

GitHub Actionsを設定し、自動テストを有効化

### 4. ドキュメント更新

テスト結果に基づいてREADMEと開発者ガイドを更新

---

## 参考資料

- [plenary.nvim テストガイド](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness)
- [Neovim Lua API](https://neovim.io/doc/user/lua.html)
- [コードベース深層分析レポート](../analysis/codebase-analysis.md)（エージェント生成）
- [コードレビューレポート](../analysis/code-review-report.md)（エージェント生成）

---

## 貢献者向けガイド

### 新しいテストケースの追加

1. 適切な優先度ディレクトリに`{番号}_{機能名}_spec.lua`を作成
2. ドキュメント`docs/e2e-tests/priority-{N}/{番号}-{機能名}.md`を作成
3. `README.md`のテストケース一覧を更新
4. プルリクエストを作成

### テストの品質基準

- ✅ 各テストは独立して実行可能
- ✅ `before_each`/`after_each`で適切なクリーンアップ
- ✅ アサーションメッセージは明確
- ✅ OS固有のテストは`pending()`で適切にスキップ
- ✅ モック/スパイは必ずクリーンアップ

---

**最終更新**: 2026-01-18
**ドキュメントバージョン**: 1.0
**テストカバレッジ目標**: 90%（コア機能）
