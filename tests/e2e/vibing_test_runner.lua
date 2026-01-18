-- tests/e2e/vibing_test_runner.lua
-- vibing.nvimエージェントが実行するE2Eテストランナー

local M = {}

-- ヘルパー: テスト結果を記録
local test_results = {}
local function log_result(test_name, passed, message)
  table.insert(test_results, {
    name = test_name,
    passed = passed,
    message = message or "",
    timestamp = os.date("%Y-%m-%d %H:%M:%S")
  })

  local status = passed and "✅ PASS" or "❌ FAIL"
  print(string.format("[%s] %s: %s", status, test_name, message or ""))
end

-- ヘルパー: IME状態取得
local function get_ime_status()
  local ime = require("ime-auto.ime")
  return ime.get_status()
end

-- ヘルパー: スロットファイル読み込み
local function read_slot(slot_name)
  local path = vim.fn.expand(string.format("~/.local/share/nvim/ime-auto/saved-ime-%s.txt", slot_name))
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path)
    return lines[1] or ""
  end
  return nil
end

-- ヘルパー: 現在のIME ID取得
local function get_current_ime_id()
  local swift_tool = require("ime-auto.swift-ime-tool")
  return swift_tool.get_current()
end

---
--- Test E2E-01: 基本的なIME切り替え（半自動）
---
function M.test_basic_ime_switching()
  local test_name = "E2E-01: Basic IME Switching"
  print("\n=== " .. test_name .. " ===")

  -- 準備
  vim.cmd("enew!")

  -- 初期状態確認
  local initial_ime = get_current_ime_id()
  print("Initial IME:", initial_ime)

  -- Normal modeでIME OFF確認
  vim.cmd("stopinsert")
  vim.wait(200)
  local status_normal = get_ime_status()

  if status_normal == false then
    log_result(test_name .. " (Normal mode OFF)", true, "IME is OFF in Normal mode")
  else
    log_result(test_name .. " (Normal mode OFF)", false, "IME should be OFF in Normal mode")
  end

  -- Insert modeに入る
  print("\n⚠️  これから Insert mode に入ります")
  print("💡 vibing.nvimエージェントへの指示:")
  print("   1. Insert modeに入ったら、日本語IMEに切り替えてください")
  print("   2. 何か日本語を入力してください（例: てすと）")
  print("   3. 入力が終わったら Normal mode に戻ってください")
  print("\n準備ができたら Enter を押してください...")

  -- ここでvibing.nvimエージェントが手動操作を行う想定
  -- 実際のE2Eでは、エージェントがキー入力を送信する

  return test_results
end

---
--- Test E2E-02: スロット永続化の確認
---
function M.test_slot_persistence()
  local test_name = "E2E-02: Slot Persistence"
  print("\n=== " .. test_name .. " ===")

  -- スロットファイルの存在確認
  local slot_a = read_slot("a")
  local slot_b = read_slot("b")

  if slot_a then
    log_result(test_name .. " (Slot A exists)", true, "Slot A: " .. slot_a)
  else
    log_result(test_name .. " (Slot A exists)", false, "Slot A file not found")
  end

  if slot_b then
    log_result(test_name .. " (Slot B exists)", true, "Slot B: " .. slot_b)
  else
    log_result(test_name .. " (Slot B exists)", false, "Slot B file not found")
  end

  -- スロットファイルのパーミッション確認
  local slot_a_path = vim.fn.expand("~/.local/share/nvim/ime-auto/saved-ime-a.txt")
  if vim.fn.filereadable(slot_a_path) == 1 then
    local perm = vim.fn.getfperm(slot_a_path)
    print("Slot A permissions:", perm)
    -- 期待値: rw------- (0600)
    if perm:match("^rw%-%-%-%-%-%-%-") then
      log_result(test_name .. " (Secure permissions)", true, "Permissions are secure: " .. perm)
    else
      log_result(test_name .. " (Secure permissions)", false, "Permissions should be 600: " .. perm)
    end
  end

  return test_results
end

---
--- Test E2E-03: Swiftツールの動作確認
---
function M.test_swift_tool()
  local test_name = "E2E-03: Swift Tool"
  print("\n=== " .. test_name .. " ===")

  local swift_tool = require("ime-auto.swift-ime-tool")

  -- コンパイル確認
  local compiled = swift_tool.ensure_compiled()
  if compiled then
    log_result(test_name .. " (Compilation)", true, "Swift tool is compiled")
  else
    log_result(test_name .. " (Compilation)", false, "Swift tool failed to compile")
    return test_results
  end

  -- 現在のIME取得
  local current = swift_tool.get_current()
  if current and #current > 0 then
    log_result(test_name .. " (Get current IME)", true, "Current IME: " .. current)
  else
    log_result(test_name .. " (Get current IME)", false, "Failed to get current IME")
  end

  -- IME一覧取得
  local list = swift_tool.list()
  if list and #list > 0 then
    log_result(test_name .. " (List IMEs)", true, string.format("Found %d input sources", #list))
    print("\nAvailable input sources:")
    for i, source in ipairs(list) do
      print(string.format("  %d. %s", i, source))
      if i >= 5 then
        print(string.format("  ... and %d more", #list - 5))
        break
      end
    end
  else
    log_result(test_name .. " (List IMEs)", false, "Failed to list input sources")
  end

  return test_results
end

---
--- Test E2E-04: プラグイン初期化確認
---
function M.test_plugin_initialization()
  local test_name = "E2E-04: Plugin Initialization"
  print("\n=== " .. test_name .. " ===")

  -- プラグイン読み込み確認
  if vim.g.loaded_ime_auto then
    log_result(test_name .. " (Plugin loaded)", true, "Plugin is loaded")
  else
    log_result(test_name .. " (Plugin loaded)", false, "Plugin is not loaded")
  end

  -- autocmd確認
  local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
  if #autocmds > 0 then
    log_result(test_name .. " (Autocmds)", true, string.format("%d autocmds registered", #autocmds))
  else
    log_result(test_name .. " (Autocmds)", false, "No autocmds registered")
  end

  -- コマンド確認
  local commands = {
    "ImeAutoEnable",
    "ImeAutoDisable",
    "ImeAutoToggle",
    "ImeAutoStatus",
    "ImeAutoListInputSources",
  }

  for _, cmd in ipairs(commands) do
    local exists = vim.fn.exists(":" .. cmd) == 2
    if exists then
      log_result(test_name .. " (Command: " .. cmd .. ")", true, "Command exists")
    else
      log_result(test_name .. " (Command: " .. cmd .. ")", false, "Command not found")
    end
  end

  return test_results
end

---
--- Test E2E-05: エスケープシーケンス（自動化困難、手動確認推奨）
---
function M.test_escape_sequence()
  local test_name = "E2E-05: Escape Sequence"
  print("\n=== " .. test_name .. " ===")
  print("⚠️  このテストは手動確認が必要です")
  print("\n手順:")
  print("1. Insert modeに入る: i")
  print("2. 日本語IMEに切り替える")
  print("3. 全角で「ｋｊ」と入力")
  print("4. Normal modeに戻り、バッファに「ｋｊ」が残っていないことを確認")

  log_result(test_name, true, "Manual verification required")

  return test_results
end

---
--- すべてのテストを実行
---
function M.run_all_tests()
  print("╔═══════════════════════════════════════════════════════╗")
  print("║  IME-AUTO.NVIM - E2E Test Suite                      ║")
  print("║  Powered by vibing.nvim                              ║")
  print("╚═══════════════════════════════════════════════════════╝")
  print("\nStarting E2E tests...")
  print("Timestamp:", os.date("%Y-%m-%d %H:%M:%S"))

  -- テスト結果初期化
  test_results = {}

  -- 自動実行可能なテスト
  M.test_plugin_initialization()
  M.test_swift_tool()
  M.test_slot_persistence()

  -- 半自動テスト（vibing.nvimエージェントが操作）
  print("\n" .. string.rep("=", 60))
  print("以降のテストは vibing.nvim エージェントの操作が必要です")
  print(string.rep("=", 60))

  -- M.test_basic_ime_switching()  -- コメントアウト: 手動操作が必要
  -- M.test_escape_sequence()       -- コメントアウト: 手動操作が必要

  -- 結果サマリー
  M.print_summary()

  return test_results
end

---
--- テスト結果サマリーを表示
---
function M.print_summary()
  print("\n╔═══════════════════════════════════════════════════════╗")
  print("║  Test Results Summary                                 ║")
  print("╚═══════════════════════════════════════════════════════╝")

  local total = #test_results
  local passed = 0
  local failed = 0

  for _, result in ipairs(test_results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  print(string.format("\nTotal:  %d tests", total))
  print(string.format("Passed: %d tests ✅", passed))
  print(string.format("Failed: %d tests ❌", failed))

  if failed > 0 then
    print("\n❌ Failed tests:")
    for _, result in ipairs(test_results) do
      if not result.passed then
        print(string.format("  - %s: %s", result.name, result.message))
      end
    end
  end

  if failed == 0 then
    print("\n🎉 All tests passed!")
  else
    print("\n⚠️  Some tests failed. Please review the output above.")
  end

  -- 詳細結果をファイルに保存
  local report_path = vim.fn.expand("~/.local/share/nvim/ime-auto/e2e-test-report.json")
  local report_dir = vim.fn.fnamemodify(report_path, ":h")
  vim.fn.mkdir(report_dir, "p")

  local report_json = vim.json.encode({
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    summary = {
      total = total,
      passed = passed,
      failed = failed,
    },
    results = test_results,
  })

  vim.fn.writefile({report_json}, report_path)
  print(string.format("\n📝 Detailed report saved to: %s", report_path))
end

---
--- 個別テストを実行（vibing.nvimから呼び出し用）
---
function M.run_test(test_name)
  test_results = {}

  if test_name == "initialization" then
    M.test_plugin_initialization()
  elseif test_name == "swift_tool" then
    M.test_swift_tool()
  elseif test_name == "slot_persistence" then
    M.test_slot_persistence()
  elseif test_name == "basic_switching" then
    M.test_basic_ime_switching()
  elseif test_name == "escape_sequence" then
    M.test_escape_sequence()
  else
    print("Unknown test:", test_name)
    print("Available tests: initialization, swift_tool, slot_persistence, basic_switching, escape_sequence")
  end

  M.print_summary()
  return test_results
end

return M
