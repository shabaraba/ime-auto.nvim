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

-- Get Swift source code path
local function get_swift_source_path()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
  return plugin_root .. "/swift/ime-tool.swift"
end

-- Load Swift source code from file
local function load_swift_source()
  local swift_path = get_swift_source_path()
  local file = io.open(swift_path, 'r')
  if not file then
    return nil, "Swift source file not found: " .. swift_path
  end
  local content = file:read('*a')
  file:close()
  return content, nil
end

-- Swift source code for IME control (lazy-loaded)
local swift_source = nil

-- Check if recompilation is needed based on source mtime
local function needs_recompilation(source_path, binary_path)
  local source_mtime = vim.fn.getftime(source_path)
  local binary_mtime = vim.fn.getftime(binary_path)

  -- Binary doesn't exist
  if binary_mtime == -1 then
    return true
  end

  -- Source doesn't exist (shouldn't happen)
  if source_mtime == -1 then
    return false
  end

  -- Source is newer than binary
  return source_mtime > binary_mtime
end

-- Compile Swift tool if not already compiled
function M.ensure_compiled()
  if swift_bin_path and vim.fn.filereadable(swift_bin_path) == 1 then
    return true
  end

  local data_dir = vim.fn.stdpath('data')
  local ime_dir = data_dir .. '/ime-auto'
  local source_path = ime_dir .. '/swift-ime.swift'
  swift_bin_path = ime_dir .. '/swift-ime'

  -- Create directory if it doesn't exist
  vim.fn.mkdir(ime_dir, 'p')

  -- Check if binary already exists and is up-to-date
  if vim.fn.filereadable(swift_bin_path) == 1 then
    local swift_src_path = get_swift_source_path()
    if not needs_recompilation(swift_src_path, swift_bin_path) then
      return true
    end
  end

  -- Lazy-load Swift source code on first compile
  if not swift_source then
    local err
    swift_source, err = load_swift_source()
    if not swift_source then
      return false, err
    end
  end

  -- Write Swift source code
  local file = io.open(source_path, 'w')
  if not file then
    return false, "Failed to open Swift source file for writing: " .. source_path
  end

  local write_ok, write_err = file:write(swift_source)
  if not write_ok then
    file:close()
    return false, "Failed to write Swift source to " .. source_path .. ": " .. tostring(write_err)
  end

  local close_ok, close_err = file:close()
  if not close_ok then
    return false, "Failed to close Swift source file " .. source_path .. ": " .. tostring(close_err)
  end

  -- Compile Swift code
  local compile_cmd = string.format('swiftc "%s" -o "%s" 2>&1', source_path, swift_bin_path)
  local result = vim.fn.system(compile_cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Failed to compile Swift tool: " .. result
  end

  return true
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
