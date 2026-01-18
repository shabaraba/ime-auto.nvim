--- Swift IME Tool Integration Module
---
--- This module provides integration with the Swift-based IME control tool for macOS.
--- It handles:
--- - Swift tool compilation and caching (with mtime-based recompilation detection)
--- - IME state detection and switching via Carbon APIs
--- - Slot-based IME state management (slot A: Insert mode, slot B: Normal mode)
--- - Error handling and retry logic
--- - Input validation for security
---
--- @module ime-auto.swift-ime-tool

local M = {}

local swift_bin_path = nil

-- Constants
local SYSTEM_CALL_TIMEOUT_MS = 5000  -- 5 second timeout for Swift tool calls

local function run_swift_command(args)
  local ok, err = M.ensure_compiled()
  if not ok then
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.ERROR)
    end
    return nil, false
  end

  local cmd
  if args then
    cmd = string.format('%s %s', vim.fn.shellescape(swift_bin_path), vim.fn.shellescape(args))
  else
    cmd = vim.fn.shellescape(swift_bin_path)
  end
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  return result, success
end

local function trim(str)
  if not str then return nil end
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end


-- Get plugin root directory
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return vim.fn.fnamemodify(source, ":h:h:h")
end

-- Find precompiled binary (priority: plugin bin/ > user-compiled)
local function find_precompiled_binary()
  local plugin_root = get_plugin_root()
  local precompiled_path = plugin_root .. "/bin/swift-ime"

  if vim.fn.filereadable(precompiled_path) == 1 then
    return precompiled_path
  end

  return nil
end

-- Ensure Swift binary is available
function M.ensure_compiled()
  if swift_bin_path and vim.fn.filereadable(swift_bin_path) == 1 then
    return true
  end

  -- Check for precompiled binary in plugin bin/
  local precompiled = find_precompiled_binary()
  if precompiled then
    swift_bin_path = precompiled
    return true
  end

  -- Binary not found
  local plugin_root = get_plugin_root()
  return false, string.format(
    "Swift IME tool binary not found at: %s/bin/swift-ime\n\n" ..
    "This is unexpected. Please try:\n" ..
    "1. Reinstall the plugin\n" ..
    "2. If you're a developer, run: ./scripts/build-universal-binary.sh\n" ..
    "3. Report this issue at: https://github.com/shabaraba/ime-auto.nvim/issues",
    plugin_root
  )
end

function M.get_current()
  local result, success = run_swift_command(nil)
  if success and result then
    return trim(result)
  end
  return nil
end

function M.switch_to(source_id)
  -- Validate input source ID format to prevent injection
  if not source_id or type(source_id) ~= "string" then
    return false
  end

  -- Input source IDs should only contain alphanumeric, dots, hyphens, and underscores
  if not source_id:match("^[%w%.%-_]+$") then
    vim.notify("[ime-auto] Invalid input source ID format: " .. source_id, vim.log.levels.ERROR)
    return false
  end

  local _, success = run_swift_command(source_id)
  return success
end

function M.list()
  local result, success = run_swift_command("list")
  if not success or not result then
    return nil
  end

  local sources = {}
  for line in result:gmatch("[^\r\n]+") do
    if line ~= "" then
      table.insert(sources, line)
    end
  end
  return sources
end

function M.toggle()
  local _, success = run_swift_command("toggle")
  return success
end

function M.save_insert_ime()
  local _, success = run_swift_command("save-insert")
  return success
end

function M.save_normal_ime()
  local _, success = run_swift_command("save-normal")
  return success
end

function M.toggle_from_insert()
  local _, success = run_swift_command("toggle-from-insert")
  return success
end

function M.toggle_from_normal()
  local _, success = run_swift_command("toggle-from-normal")
  return success
end

return M
