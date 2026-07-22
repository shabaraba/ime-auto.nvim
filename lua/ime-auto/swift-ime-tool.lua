--- Swift IME Tool Integration for macOS
--- @module ime-auto.swift-ime-tool

local M = {}
local utils = require("ime-auto.utils")

local swift_bin_path = nil

-- Sanitize a raw identifier to the character set accepted by the Swift tool
-- (alphanumeric, dot, dash, underscore). Exposed for testability; pure
-- function with no side effects.
function M.sanitize_instance_id(raw)
  local id = (raw or ""):gsub("[^%w%.%-_]", "_")
  if id == "" then
    id = tostring(vim.fn.getpid())
  end
  return id
end

-- Unique identifier for this Neovim instance, used to isolate slot files
-- between concurrently running instances (see issue #31)
local function get_instance_id()
  local raw = vim.v.servername
  if not raw or raw == "" then
    raw = tostring(vim.fn.getpid())
  end
  return M.sanitize_instance_id(raw)
end

-- Enable debug logging if ime-auto debug is enabled
local function build_env()
  local config = require("ime-auto.config").get()
  if config.debug then
    return { IME_AUTO_DEBUG = "1" }
  end
  return nil
end

-- args: nil, or a list of positional arguments passed to the Swift binary
local function build_argv(args)
  local argv = { swift_bin_path }
  if args then
    for _, arg in ipairs(args) do
      table.insert(argv, arg)
    end
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

-- Returns true if IME is composing (non-ASCII), false if ASCII/English mode,
-- or nil if the status could not be determined. Trusts the Swift tool's
-- TIS-property-based judgment rather than re-deriving it from the ID string.
function M.get_status()
  local result, success = run_swift_command({ "status" })
  if not success or not result then
    return nil
  end

  local trimmed = utils.trim(result)
  if trimmed == "on" then
    return true
  elseif trimmed == "off" then
    return false
  end
  return nil
end

function M.list()
  local result, success = run_swift_command({ "list" })
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

-- Fire-and-forget: the InsertLeave path doesn't need to wait for the result,
-- so switching happens asynchronously to avoid blocking the editor.
function M.toggle_from_insert(callback)
  run_swift_command_async({ "toggle-from-insert", get_instance_id() }, function(_, success)
    if callback then
      callback(success)
    end
  end)
end

-- Fire-and-forget: the InsertEnter path doesn't need to wait for the result,
-- so switching happens asynchronously to avoid blocking the editor.
function M.toggle_from_normal(callback)
  run_swift_command_async({ "toggle-from-normal", get_instance_id() }, function(_, success)
    if callback then
      callback(success)
    end
  end)
end

return M
