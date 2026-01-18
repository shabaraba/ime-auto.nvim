# ime-auto.nvim E2Eテストスイート

このディレクトリには、ime-auto.nvimの包括的なE2Eテストケースが含まれています。

## 📋 テストケース一覧

テストケースは3つの優先度に分類されています：

### Priority 1: Critical（必須）

これらのテストは、プラグインのコア機能を検証します。**必ず実装・実行する必要があります。**

1. [基本的なIME切り替え](./priority-1-critical/01-basic-ime-switching.md)
2. [高速モード切り替えでの競合状態](./priority-1-critical/02-rapid-mode-switching.md)
3. [マルチバイト文字境界の正確性](./priority-1-critical/03-multibyte-char-boundaries.md)
4. [Swiftツールのコンパイルとリカバリ](./priority-1-critical/04-swift-tool-compilation.md) (macOS専用)
5. [IME状態の保存と復元](./priority-1-critical/05-ime-state-persistence.md)

### Priority 2: Important（推奨）

これらのテストは、エッジケースとエラーハンドリングを検証します。

6. [リソースクリーンアップ](./priority-2-important/06-resource-cleanup.md)
7. [設定バリデーション](./priority-2-important/07-config-validation.md)
8. [macOS slot初期化](./priority-2-important/08-macos-slot-initialization.md) (macOS専用)
9. [UIモジュールの堅牢性](./priority-2-important/09-ui-robustness.md)

### Priority 3: Normal（あると良い）

これらのテストは、プラットフォーム固有の動作と追加機能を検証します。

10. [OS別動作確認](./priority-3-normal/10-os-specific-behavior.md)
11. [設定変更の即時反映](./priority-3-normal/11-runtime-config-changes.md)
12. [デバッグモード](./priority-3-normal/12-debug-mode.md)

## 🎯 テスト戦略

### テスト環境

- **Neovim**: v0.9.0以降
- **OS**: macOS, Windows, Linux
- **テストフレームワーク**: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### 実行方法

```bash
# 全テスト実行
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# 特定のテストファイル実行
nvim --headless -c "PlenaryBustedFile tests/basic_ime_switching_spec.lua { minimal_init = 'tests/minimal_init.lua' }"

# Priority 1のみ実行
nvim --headless -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }"
```

## 📊 テストカバレッジ目標

| カテゴリ | 目標カバレッジ |
|---------|--------------|
| コア機能（init.lua, ime.lua, escape.lua） | 90%以上 |
| プラットフォーム固有（swift-ime-tool.lua） | 80%以上 |
| UI・ユーティリティ（ui.lua, utils.lua） | 70%以上 |

## 🔍 コードレビューで発見された主要な問題

詳細な分析により、以下の潜在的な問題が特定されました：

### Critical Issues

1. **競合状態**: IMEキャッシュとデバウンスの組み合わせ
   - 高速なモード切り替え時にキャッシュが古い状態を返す可能性
   - テスト: [02-rapid-mode-switching.md](./priority-1-critical/02-rapid-mode-switching.md)

2. **文字境界問題**: エスケープシーケンス処理でのマルチバイト文字
   - `strpart()`と`strcharpart()`の混在による境界計算エラー
   - テスト: [03-multibyte-char-boundaries.md](./priority-1-critical/03-multibyte-char-boundaries.md)

3. **Swiftコンパイル失敗**: リトライ機構なし
   - 一時的なエラーで永続的に失敗
   - テスト: [04-swift-tool-compilation.md](./priority-1-critical/04-swift-tool-compilation.md)

4. **restore_state()の意味的不整合**: macOS専用ロジック
   - 常にIME ONにする動作がユーザー意図と不一致の可能性
   - テスト: [08-macos-slot-initialization.md](./priority-2-important/08-macos-slot-initialization.md)

### Important Issues

5. **タイマークリーンアップ漏れ**: プラグイン無効化時
   - `:ImeAutoDisable`後もタイマーが発火する可能性
   - テスト: [06-resource-cleanup.md](./priority-2-important/06-resource-cleanup.md)

6. **無限ループリスク**: UIモジュールのキー入力ループ
   - タイムアウト機構なし
   - テスト: [09-ui-robustness.md](./priority-2-important/09-ui-robustness.md)

## 📝 テストケースドキュメントの構造

各テストケースドキュメントには以下の情報が含まれます：

- **概要**: テストの目的と重要性
- **前提条件**: 必要な環境設定
- **テストステップ**: 詳細な手順
- **期待される結果**: 成功条件
- **検証ポイント**: 確認すべき具体的な項目
- **実装例**: Lua/plenary.nvimのコードサンプル
- **関連ファイル**: 対象となるソースコードへの参照

## 🚀 次のステップ

1. ✅ テストケースドキュメント作成（このディレクトリ）
2. ⏳ テストフレームワークのセットアップ（`tests/` ディレクトリ）
3. ⏳ Priority 1テストの実装
4. ⏳ CI/CD統合（GitHub Actions）
5. ⏳ Priority 2, 3テストの実装

## 📚 参考資料

- [コードベース深層分析レポート](../analysis/codebase-analysis.md)
- [コードレビューレポート](../analysis/code-review-report.md)
- [plenary.nvim テストガイド](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness)
- [Neovim Lua API](https://neovim.io/doc/user/lua.html)

---

**最終更新**: 2026-01-18
**テストケース総数**: 12
**実装済みテスト**: 0/12
