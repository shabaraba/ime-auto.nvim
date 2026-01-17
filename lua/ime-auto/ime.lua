local M = {}

local last_ime_state = nil  -- nil means not initialized yet

local function execute_command(cmd)
  if not cmd then
    return nil
  end

  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read("*a")
  handle:close()

  return result and result:gsub("^%s+", ""):gsub("%s+$", "")
end

local function ime_control_macos(action)
  local swift_tool = require("ime-auto.swift-ime-tool")

  if action == "off" then
    -- InsertLeave: Save current Insert mode IME to slot A, switch to Normal mode IME (slot B)
    swift_tool.toggle_from_insert()
  elseif action == "on" then
    -- InsertEnter: Save current Normal mode IME to slot B, switch to Insert mode IME (slot A)
    swift_tool.toggle_from_normal()
  elseif action == "status" then
    local result = swift_tool.get_current()
    if not result then
      return false
    end

    -- Pattern matching for Japanese input sources
    return result:match("Japanese") ~= nil or result:match("Hiragana") ~= nil or result:match("Katakana") ~= nil
  end
end

local function ime_control_windows(action)
  if action == "off" then
    return vim.fn.system([[powershell -Command "[System.Windows.Forms.SendKeys]::SendWait('{KANJI}')"]])
  elseif action == "on" then
    return vim.fn.system([[powershell -Command "[System.Windows.Forms.SendKeys]::SendWait('{KANJI}')"]])
  elseif action == "status" then
    local result = execute_command([[powershell -Command "Get-WinUserLanguageList | Where-Object {$_.LanguageTag -eq 'ja-JP'} | Select-Object -ExpandProperty InputMethodTips"]])
    return result and result:match("0411:00000411") ~= nil
  end
end

local function ime_control_linux(action)
  local fcitx_exists = vim.fn.executable("fcitx-remote") == 1
  local ibus_exists = vim.fn.executable("ibus") == 1
  
  if fcitx_exists then
    if action == "off" then
      return vim.fn.system("fcitx-remote -c")
    elseif action == "on" then
      return vim.fn.system("fcitx-remote -o")
    elseif action == "status" then
      local result = execute_command("fcitx-remote")
      return result and result == "2"
    end
  elseif ibus_exists then
    if action == "off" then
      return vim.fn.system("ibus engine 'xkb:us::eng'")
    elseif action == "on" then
      return vim.fn.system("ibus engine 'mozc-jp'")
    elseif action == "status" then
      local result = execute_command("ibus engine")
      return result and result:match("mozc") ~= nil
    end
  end
  
  return nil
end

function M.control(action)
  local config = require("ime-auto.config").get()
  
  if config.ime_method == "custom" then
    local cmd = config.custom_commands[action]
    if cmd then
      return execute_command(cmd)
    end
  end
  
  local os = config.os
  local result = nil
  
  if os == "macos" then
    result = ime_control_macos(action)
  elseif os == "windows" then
    result = ime_control_windows(action)
  elseif os == "linux" then
    result = ime_control_linux(action)
  end
  
  if config.debug then
    vim.notify(string.format("[ime-auto] IME %s on %s", action, os), vim.log.levels.DEBUG)
  end
  
  return result
end

function M.off()
  local config = require("ime-auto.config").get()

  if config.debug then
    local current_status = M.get_status()
    vim.notify(string.format("[ime-auto] M.off() called, current status: %s", tostring(current_status)), vim.log.levels.DEBUG)
  end

  -- Always call control("off") to save current Insert mode IME to slot A
  M.control("off")
end

function M.on()
  local config = require("ime-auto.config").get()
  if config.debug then
    vim.notify("[ime-auto] M.on() called", vim.log.levels.DEBUG)
  end
  M.control("on")
end

function M.get_status()
  local result = M.control("status")
  if type(result) == "boolean" then
    return result
  else
    return last_ime_state
  end
end

function M.save_state()
  local current = M.get_status()
  last_ime_state = current
  local config = require("ime-auto.config").get()
  if config.debug then
    vim.notify(string.format("[ime-auto] Saved IME state: %s", tostring(last_ime_state)), vim.log.levels.DEBUG)
  end
end

function M.restore_state()
  local config = require("ime-auto.config").get()

  if config.debug then
    vim.notify("[ime-auto] Restoring IME state", vim.log.levels.DEBUG)
  end

  -- For macOS, use Swift tool's load command to restore the saved state
  if config.os == "macos" then
    M.on()  -- This will call swift_tool.load_saved()
    return
  end

  -- For other OS (Windows/Linux), use the standard restore logic
  if last_ime_state == nil then
    last_ime_state = M.get_status()
    if config.debug then
      vim.notify(string.format("[ime-auto] First time: initialized state from current IME: %s", tostring(last_ime_state)), vim.log.levels.DEBUG)
    end
  end

  if last_ime_state then
    M.on()
  else
    M.off()
  end
end

function M.list_input_sources()
  local config = require("ime-auto.config").get()

  if config.os ~= "macos" then
    return nil, "This feature is only available on macOS"
  end

  local swift_tool = require("ime-auto.swift-ime-tool")
  local sources = swift_tool.list()
  if sources then
    return table.concat(sources, "\n")
  end
  return nil
end

-- Parse input source list and return array of {id, name} tables
function M.parse_input_sources()
  local config = require("ime-auto.config").get()

  if config.os ~= "macos" then
    return nil, "This feature is only available on macOS"
  end

  local swift_tool = require("ime-auto.swift-ime-tool")
  local source_list = swift_tool.list()
  local sources = {}

  if source_list then
    for _, id in ipairs(source_list) do
      local name = id:match("%.([^.]+)$") or id
      table.insert(sources, { id = id, name = name })
    end
  end

  return sources
end

return M