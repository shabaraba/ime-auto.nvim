--- Swift IME Tool Integration for macOS
--- @module ime-auto.swift-ime-tool

local M = {}
local utils = require("ime-auto.utils")

local swift_bin_path = nil

-- Enable debug logging if ime-auto debug is enabled
local function build_env()
  local config = require("ime-auto.config").get()
  if config.debug then
    return { IME_AUTO_DEBUG = "1" }
  end
  return nil
end

local function build_argv(args)
  local argv = { swift_bin_path }
  if args then
    table.insert(argv, args)
  end
  return argv
end

-- Synchronous invocation for callers that need the result immediately
-- (e.g. user-triggered commands like :Status, :ListInputSources)
local function run_swift_command(args)
  local ok, err = M.ensure_compiled()
  if not ok then
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.ERROR)
    end
    return nil, false
  end

  local result = vim.system(build_argv(args), { text = true, env = build_env() }):wait()
  return result.stdout, result.code == 0
end

-- Asynchronous invocation for hot-path callers (InsertEnter/InsertLeave) that
-- must not block the main loop while the Swift binary switches IME state
local function run_swift_command_async(args, callback)
  local ok, err = M.ensure_compiled()
  if not ok then
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.ERROR)
    end
    if callback then
      callback(nil, false)
    end
    return
  end

  vim.system(build_argv(args), { text = true, env = build_env() }, function(result)
    if not callback then
      return
    end
    vim.schedule(function()
      callback(result.stdout, result.code == 0)
    end)
  end)
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
    return utils.trim(result)
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

-- Fire-and-forget: the InsertLeave path doesn't need to wait for the result,
-- so switching happens asynchronously to avoid blocking the editor.
function M.toggle_from_insert(callback)
  run_swift_command_async("toggle-from-insert", function(_, success)
    if callback then
      callback(success)
    end
  end)
end

-- Fire-and-forget: the InsertEnter path doesn't need to wait for the result,
-- so switching happens asynchronously to avoid blocking the editor.
function M.toggle_from_normal(callback)
  run_swift_command_async("toggle-from-normal", function(_, success)
    if callback then
      callback(success)
    end
  end)
end

return M
