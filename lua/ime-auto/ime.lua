--- IME Control Module for cross-platform IME management
--- @module ime-auto.ime

local M = {}
local platform = require("ime-auto.ime-platform")
local utils = require("ime-auto.utils")

local last_ime_state = nil

-- IME state cache with TTL
local ime_state_cache = {
  value = nil,
  timestamp = 0,
  ttl_ms = 500
}

local function invalidate_ime_state_cache()
  ime_state_cache.value = nil
end

local function execute_command(cmd)
  if not cmd then return nil end

  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    utils.notify(
      string.format("Command failed (exit code %d): %s", exit_code, cmd),
      vim.log.levels.ERROR
    )
    return nil
  end

  return utils.trim(result)
end

local function custom_status_to_boolean(result, pattern)
  if result == nil then return nil end

  if not pattern then
    utils.notify(
      "custom_status_true_pattern is not configured; cannot determine IME status for ime_method='custom'",
      vim.log.levels.WARN
    )
    return nil
  end

  local ok, matched = pcall(string.match, result, pattern)
  if not ok then
    utils.notify("Invalid custom_status_true_pattern: " .. tostring(matched), vim.log.levels.ERROR)
    return nil
  end

  return matched ~= nil
end

function M.control(action)
  local config = require("ime-auto.config").get()

  if action == "on" or action == "off" then
    invalidate_ime_state_cache()
  end

  if config.ime_method == "custom" then
    local cmd = config.custom_commands[action]
    if cmd then
      local result = execute_command(cmd)
      if action == "status" then
        return custom_status_to_boolean(result, config.custom_status_true_pattern)
      end
      return result
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

function M.off()
  M.control("off")
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

  -- macOS/Windows: Use slot-based management to restore Insert mode IME state
  if config.os == "macos" then
    local swift_tool = require("ime-auto.swift-ime-tool")
    swift_tool.toggle_from_normal()
    invalidate_ime_state_cache()
    return
  elseif config.os == "windows" then
    local windows_tool = require("ime-auto.windows-ime-tool")
    windows_tool.toggle_from_normal()
    return
  end

  -- Linux: Use slot-based management to restore Insert mode IME state
  if config.os == "linux" then
    local linux_tool = require("ime-auto.linux-ime-tool")
    linux_tool.toggle_from_normal()
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

return M