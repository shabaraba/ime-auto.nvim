# 貢献ガイド

ime-auto.nvim への貢献を歓迎します！

## 開発環境のセットアップ

### 必要なもの

- Neovim (最新版推奨)
- macOS の場合: Xcode Command Line Tools (`swiftc`)
- テスト用: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### リポジトリのクローン

```bash
git clone https://github.com/shabaraba/ime-auto.nvim.git
cd ime-auto.nvim
```

## テスト

### 単体テスト

Plenary.nvim を使った単体テストを実行：

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/priority-1/ { minimal_init = 'tests/minimal_init.lua' }" \
  -c "qa!"
```

### E2Eテスト

実際の IME 動作を確認する E2E テスト：

```vim
:source tests/e2e/vibing_execution_script.lua
```

または Lua から直接実行：

```lua
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"
local e2e = require("tests.e2e.vibing_test_runner")
e2e.run_all_tests()
```

### 手動テスト

詳細な手動テスト手順は以下を参照：

- [MANUAL_TEST_GUIDE.md](tests/e2e/MANUAL_TEST_GUIDE.md) - 手動テスト手順

## 開発ガイドライン

開発に関する詳細（アーキテクチャ、実装詳細、コーディング規約など）は [CLAUDE.md](CLAUDE.md) を参照してください。

### Pull Request を作成する前に

- [ ] すべての単体テストがパスすることを確認
- [ ] 新機能の場合はテストを追加
- [ ] コミットメッセージは [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716) 形式で記述

## 質問・問題報告

- **バグ報告**: [Issues](https://github.com/shabaraba/ime-auto.nvim/issues) を作成
- **機能要望**: [Issues](https://github.com/shabaraba/ime-auto.nvim/issues) を作成
- **質問**: [Discussions](https://github.com/shabaraba/ime-auto.nvim/discussions) で質問

## ライセンス

貢献したコードは MIT License の下で公開されます。
