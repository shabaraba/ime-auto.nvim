--- OS-specific IME control command execution
--- @module ime-auto.ime-platform

local M = {}
local utils = require("ime-auto.utils")

function M.execute_command(cmd)
  if not cmd then return nil end

  local handle = io.popen(cmd)
  if not handle then return nil end

  local result = handle:read("*a")
  handle:close()
  return utils.trim(result)
end

function M.macos(action)
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

function M.windows(action)
  if action == "off" then
    return vim.fn.system([[powershell -Command "[System.Windows.Forms.SendKeys]::SendWait('{KANJI}')"]])
  elseif action == "on" then
    return vim.fn.system([[powershell -Command "[System.Windows.Forms.SendKeys]::SendWait('{KANJI}')"]])
  elseif action == "status" then
    local result = M.execute_command([[powershell -Command "Get-WinUserLanguageList | Where-Object {$_.LanguageTag -eq 'ja-JP'} | Select-Object -ExpandProperty InputMethodTips"]])
    return result and result:match("0411:00000411") ~= nil
  end
end

function M.linux(action)
  local fcitx_exists = vim.fn.executable("fcitx-remote") == 1
  local ibus_exists = vim.fn.executable("ibus") == 1

  if fcitx_exists then
    if action == "off" then
      return vim.fn.system("fcitx-remote -c")
    elseif action == "on" then
      return vim.fn.system("fcitx-remote -o")
    elseif action == "status" then
      local result = M.execute_command("fcitx-remote")
      return result and result == "2"
    end
  elseif ibus_exists then
    if action == "off" then
      return vim.fn.system("ibus engine 'xkb:us::eng'")
    elseif action == "on" then
      return vim.fn.system("ibus engine 'mozc-jp'")
    elseif action == "status" then
      local result = M.execute_command("ibus engine")
      return result and result:match("mozc") ~= nil
    end
  end

  return nil
end

return M
