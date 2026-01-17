local M = {}

local last_ime_state = nil

-- IME state cache with TTL
local ime_state_cache = {
  value = nil,
  timestamp = 0,
  ttl_ms = 500  -- Cache for 500ms
}

-- Debounce timer for mode changes
local mode_change_timer = nil
local MODE_CHANGE_DEBOUNCE_MS = 100

local function trim(str)
  if not str then return nil end
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

local function execute_command(cmd)
  if not cmd then return nil end

  local handle = io.popen(cmd)
  if not handle then return nil end

  local result = handle:read("*a")
  handle:close()
  return trim(result)
end

local function ime_control_macos(action)
  local swift_tool = require("ime-auto.swift-ime-tool")

  if action == "off" then
    swift_tool.toggle_from_insert()
  elseif action == "on" then
    swift_tool.toggle_from_normal()
  elseif action == "status" then
    local result = swift_tool.get_current()
    if not result then return false end

    -- Known Japanese IME patterns
    if result:match("Japanese") or result:match("Hiragana") or result:match("Katakana") then
      return true
    end

    -- Fallback: treat non-standard ASCII identifiers as potentially active IME
    -- Standard English layouts follow pattern: com.apple.keylayout.*
    if not result:match("^[A-Za-z0-9%.%-_]+$") or not result:match("^com%.apple%.keylayout%.") then
      return true
    end

    return false
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

-- Debounced version of off()
function M.off_debounced()
  if mode_change_timer then
    vim.fn.timer_stop(mode_change_timer)
  end

  mode_change_timer = vim.fn.timer_start(MODE_CHANGE_DEBOUNCE_MS, function()
    M.control("off")
    mode_change_timer = nil
  end)
end

function M.off()
  M.control("off")
end

-- Debounced version of on()
function M.on_debounced()
  if mode_change_timer then
    vim.fn.timer_stop(mode_change_timer)
  end

  mode_change_timer = vim.fn.timer_start(MODE_CHANGE_DEBOUNCE_MS, function()
    M.control("on")
    mode_change_timer = nil
  end)
end

function M.on()
  M.control("on")
end

function M.get_status()
  -- Check cache first
  local now = vim.loop.now()
  if ime_state_cache.value ~= nil and (now - ime_state_cache.timestamp) < ime_state_cache.ttl_ms then
    return ime_state_cache.value
  end

  -- Cache miss - get actual status
  local result = M.control("status")
  local status = nil
  if type(result) == "boolean" then
    status = result
  else
    status = last_ime_state
  end

  -- Update cache
  ime_state_cache.value = status
  ime_state_cache.timestamp = now

  return status
end

function M.save_state()
  last_ime_state = M.get_status()
end

function M.restore_state()
  local config = require("ime-auto.config").get()

  if config.os == "macos" then
    M.on()
    return
  end

  if last_ime_state == nil then
    last_ime_state = M.get_status()
  end

  if last_ime_state then
    M.on()
  else
    M.off()
  end
end

local function require_macos()
  local config = require("ime-auto.config").get()
  if config.os ~= "macos" then
    return nil, "This feature is only available on macOS"
  end
  return true
end

function M.list_input_sources()
  local ok, err = require_macos()
  if not ok then return nil, err end

  local swift_tool = require("ime-auto.swift-ime-tool")
  local sources = swift_tool.list()
  return sources and table.concat(sources, "\n") or nil
end

function M.parse_input_sources()
  local ok, err = require_macos()
  if not ok then return nil, err end

  local swift_tool = require("ime-auto.swift-ime-tool")
  local source_list = swift_tool.list()
  if not source_list then return {} end

  local sources = {}
  for _, entry in ipairs(source_list) do
    -- Parse "id - name" format from swift_tool.list()
    local id, name = entry:match("^(.-)%s*%-%s*(.+)$")
    if id and name then
      table.insert(sources, { id = id, name = name })
    else
      -- Fallback: treat entire entry as ID and extract name from ID
      local fallback_name = entry:match("%.([^.]+)$") or entry
      table.insert(sources, { id = entry, name = fallback_name })
    end
  end
  return sources
end

return M