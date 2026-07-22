--- PowerShell IME Tool Integration for Windows
--- @module ime-auto.windows-ime-tool

local M = {}
local utils = require("ime-auto.utils")

local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return vim.fn.fnamemodify(source, ":h:h:h")
end

local function get_script_path()
  return get_plugin_root() .. "/powershell/ime-tool.ps1"
end

-- Action must be one of the script's known values to prevent injection
function M.is_valid_action(action)
  return type(action) == "string" and action:match("^[%w%-]+$") ~= nil
end

function M.build_command(script_path, action)
  return string.format(
    "powershell -NoProfile -ExecutionPolicy Bypass -File %s -Action %s",
    vim.fn.shellescape(script_path),
    vim.fn.shellescape(action)
  )
end

local function run_powershell_command(action)
  if not M.is_valid_action(action) then
    vim.notify("[ime-auto] Invalid action: " .. tostring(action), vim.log.levels.ERROR)
    return nil, false
  end

  local script_path = get_script_path()
  if vim.fn.filereadable(script_path) == 0 then
    vim.notify("[ime-auto] PowerShell IME tool not found at: " .. script_path, vim.log.levels.ERROR)
    return nil, false
  end

  local cmd = M.build_command(script_path, action)
  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0
  return result, success
end

function M.get_current()
  local result, success = run_powershell_command("get-current")
  if success and result then
    return utils.trim(result)
  end
  return nil
end

function M.toggle_from_insert()
  local _, success = run_powershell_command("toggle-from-insert")
  return success
end

function M.toggle_from_normal()
  local _, success = run_powershell_command("toggle-from-normal")
  return success
end

return M
