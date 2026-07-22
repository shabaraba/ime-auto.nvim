--- IME Control Module for cross-platform IME management
--- @module ime-auto.ime

local M = {}
local platform = require("ime-auto.ime-platform")

local last_ime_state = nil

-- IME state cache with TTL
local ime_state_cache = {
  value = nil,
  timestamp = 0,
  ttl_ms = 500
}

-- Debounce timer for mode changes
local mode_change_timer = nil
local MODE_CHANGE_DEBOUNCE_MS = 100

function M.control(action)
  local config = require("ime-auto.config").get()

  if config.ime_method == "custom" then
    local cmd = config.custom_commands[action]
    if cmd then
      return platform.execute_command(cmd)
    end
  end

  local os = config.os
  local result = nil

  if os == "macos" then
    result = platform.macos(action)
  elseif os == "windows" then
    result = platform.windows(action)
  elseif os == "linux" then
    result = platform.linux(action)
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

  -- macOS: Use slot-based management to restore Insert mode IME state
  if config.os == "macos" then
    local swift_tool = require("ime-auto.swift-ime-tool")
    swift_tool.toggle_from_normal()
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