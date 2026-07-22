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

-- args: nil, or a list of positional arguments passed to the Swift binary
local function run_swift_command(args)
  local ok, err = M.ensure_compiled()
  if not ok then
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.ERROR)
    end
    return nil, false
  end

  -- Enable debug logging if ime-auto debug is enabled
  local config = require("ime-auto.config").get()
  local env_prefix = config.debug and "IME_AUTO_DEBUG=1 " or ""

  local parts = { vim.fn.shellescape(swift_bin_path) }
  if args then
    for _, arg in ipairs(args) do
      table.insert(parts, vim.fn.shellescape(arg))
    end
  end
  local cmd = env_prefix .. table.concat(parts, " ")
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  return result, success
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

  local _, success = run_swift_command({ source_id })
  return success
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

function M.toggle()
  local _, success = run_swift_command({ "toggle", get_instance_id() })
  return success
end

function M.save_insert_ime()
  local _, success = run_swift_command({ "save-insert", get_instance_id() })
  return success
end

function M.save_normal_ime()
  local _, success = run_swift_command({ "save-normal", get_instance_id() })
  return success
end

function M.toggle_from_insert()
  local _, success = run_swift_command({ "toggle-from-insert", get_instance_id() })
  return success
end

function M.toggle_from_normal()
  local _, success = run_swift_command({ "toggle-from-normal", get_instance_id() })
  return success
end

return M
