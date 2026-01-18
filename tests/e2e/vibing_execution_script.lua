-- tests/e2e/vibing_execution_script.lua
-- vibing.nvimエージェントが直接実行するスクリプト

print("╔═══════════════════════════════════════════════════════════════╗")
print("║  IME-AUTO.NVIM - E2E Test Execution                           ║")
print("║  Powered by vibing.nvim                                       ║")
print("╚═══════════════════════════════════════════════════════════════╝")
print("")

-- プロジェクトルートをモジュールパスに追加
local project_root = vim.fn.getcwd()
package.path = package.path .. ";" .. project_root .. "/?.lua"

---
--- Task 1: 環境確認
---
print("┌───────────────────────────────────────────────────────────────┐")
print("│ Task 1: Environment Check                                    │")
print("└───────────────────────────────────────────────────────────────┘")

local env_ok = true

-- Neovimバージョン
local nvim_version = vim.version()
print(string.format("Neovim version: %d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch))
if nvim_version.major == 0 and nvim_version.minor < 8 then
  print("❌ Neovim 0.8 or higher is required")
  env_ok = false
else
  print("✅ Neovim version OK")
end

-- OS確認
local os_name = vim.loop.os_uname().sysname
print("OS:", os_name)
if os_name ~= "Darwin" then
  print("❌ macOS is required for IME switching")
  env_ok = false
else
  print("✅ macOS detected")
end

-- swiftc確認
local has_swiftc = vim.fn.executable("swiftc") == 1
print("swiftc available:", has_swiftc)
if not has_swiftc then
  print("❌ swiftc not found. Install Xcode Command Line Tools:")
  print("   xcode-select --install")
  env_ok = false
else
  print("✅ swiftc available")
end

-- プラグイン読み込み確認
local plugin_loaded = vim.g.loaded_ime_auto
print("Plugin loaded:", plugin_loaded)
if not plugin_loaded then
  print("❌ ime-auto.nvim is not loaded")
  env_ok = false
else
  print("✅ Plugin loaded")
end

print("")

if not env_ok then
  print("❌ Environment check failed. Please fix the issues above.")
  return
end

---
--- Task 2: 自動テスト実行
---
print("┌───────────────────────────────────────────────────────────────┐")
print("│ Task 2: Running Automated Tests                              │")
print("└───────────────────────────────────────────────────────────────┘")

local e2e = require("tests.e2e.vibing_test_runner")
local results = e2e.run_all_tests()

print("")

---
--- Task 3: スロットファイル確認
---
print("┌───────────────────────────────────────────────────────────────┐")
print("│ Task 3: Checking Slot Files                                  │")
print("└───────────────────────────────────────────────────────────────┘")

local slot_dir = vim.fn.expand("~/.local/share/nvim/ime-auto")
print("Slot directory:", slot_dir)

local slot_a_path = slot_dir .. "/saved-ime-a.txt"
local slot_b_path = slot_dir .. "/saved-ime-b.txt"

if vim.fn.filereadable(slot_a_path) == 1 then
  local content = vim.fn.readfile(slot_a_path)[1]
  local perm = vim.fn.getfperm(slot_a_path)
  print("✅ Slot A exists:", content)
  print("   Permissions:", perm)
else
  print("⚠️  Slot A not found (will be created on first IME switch)")
end

if vim.fn.filereadable(slot_b_path) == 1 then
  local content = vim.fn.readfile(slot_b_path)[1]
  local perm = vim.fn.getfperm(slot_b_path)
  print("✅ Slot B exists:", content)
  print("   Permissions:", perm)
else
  print("⚠️  Slot B not found (will be created on first IME switch)")
end

print("")

---
--- Task 4: 実際のIME動作確認（手動操作が必要）
---
print("┌───────────────────────────────────────────────────────────────┐")
print("│ Task 4: Manual IME Switching Test                            │")
print("└───────────────────────────────────────────────────────────────┘")

print("⚠️  This task requires manual IME switching")
print("")
print("Manual test steps:")
print("1. Enter Insert mode: i")
print("2. Switch to Japanese IME (Ctrl+Space or ⌘+Space)")
print("3. Type some Japanese text: てすと")
print("4. Return to Normal mode: <Esc>")
print("5. Check if IME switched to English")
print("6. Enter Insert mode again: i")
print("7. Check if Japanese IME is restored")
print("")
print("📖 For detailed steps, see: tests/e2e/MANUAL_TEST_GUIDE.md")
print("")

---
--- Task 5: テスト結果レポート
---
print("┌───────────────────────────────────────────────────────────────┐")
print("│ Task 5: Test Results Report                                  │")
print("└───────────────────────────────────────────────────────────────┘")

local report_path = vim.fn.expand("~/.local/share/nvim/ime-auto/e2e-test-report.json")
if vim.fn.filereadable(report_path) == 1 then
  print("✅ Detailed test report saved to:")
  print("   " .. report_path)
  print("")

  -- レポート読み込み
  local report_content = vim.fn.readfile(report_path)
  local report_data = vim.json.decode(table.concat(report_content, "\n"))

  print("Summary:")
  print(string.format("  Total tests:  %d", report_data.summary.total))
  print(string.format("  Passed:       %d ✅", report_data.summary.passed))
  print(string.format("  Failed:       %d ❌", report_data.summary.failed))

  if report_data.summary.failed > 0 then
    print("")
    print("Failed tests:")
    for _, result in ipairs(report_data.results) do
      if not result.passed then
        print(string.format("  ❌ %s", result.name))
        print(string.format("     %s", result.message))
      end
    end
  end
else
  print("⚠️  No test report found")
end

print("")

---
--- 完了メッセージ
---
print("╔═══════════════════════════════════════════════════════════════╗")
print("║  E2E Test Execution Complete                                  ║")
print("╚═══════════════════════════════════════════════════════════════╝")
print("")
print("Next steps:")
print("1. Review the test report: " .. report_path)
print("2. Run manual tests (Task 4) to verify IME switching")
print("3. Check MANUAL_TEST_GUIDE.md for detailed test scenarios")
print("")
print("For vibing.nvim agent:")
print("- Automated tests: ✅ Complete")
print("- Manual tests: ⚠️  Requires human interaction")
print("")
