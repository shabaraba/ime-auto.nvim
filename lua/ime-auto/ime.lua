local M = {}

local last_ime_state = false

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
  local config = require("ime-auto.config").get()
  local tool = config.macos_ime_tool
  local en_source = config.macos_input_source_en
  local ja_source = config.macos_input_source_ja

  -- External CLI tools: macime, macism, im-select
  if tool == "macime" then
    if action == "off" then
      return vim.fn.system("macime set " .. en_source)
    elseif action == "on" then
      return vim.fn.system("macime set " .. ja_source)
    elseif action == "status" then
      local result = execute_command("macime get")
      return result and (result:match("Japanese") or result:match("Hiragana") or result:match("Katakana") or result:match(ja_source)) ~= nil
    end
  elseif tool == "macism" then
    if action == "off" then
      return vim.fn.system("macism " .. en_source)
    elseif action == "on" then
      return vim.fn.system("macism " .. ja_source)
    elseif action == "status" then
      local result = execute_command("macism")
      return result and (result:match("Japanese") or result:match("Hiragana") or result:match("Katakana") or result:match(ja_source)) ~= nil
    end
  elseif tool == "im-select" then
    if action == "off" then
      return vim.fn.system("im-select " .. en_source)
    elseif action == "on" then
      return vim.fn.system("im-select " .. ja_source)
    elseif action == "status" then
      local result = execute_command("im-select")
      return result and (result:match("Japanese") or result:match("Hiragana") or result:match("Katakana") or result:match(ja_source)) ~= nil
    end
  else
    -- Default: osascript (built-in)
    if action == "off" then
      return vim.fn.system("osascript -e 'tell application \"System Events\" to key code 102'")
    elseif action == "on" then
      return vim.fn.system("osascript -e 'tell application \"System Events\" to key code 104'")
    elseif action == "status" then
      local result = execute_command("defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep -E 'Japanese|Hiragana|Katakana' | wc -l")
      return result and tonumber(result) > 0
    end
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
  if not M.get_status() then
    return
  end
  M.control("off")
end

function M.on()
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
  last_ime_state = M.get_status()
end

function M.restore_state()
  if last_ime_state then
    M.on()
  else
    M.off()
  end
end

return M