--- Linux IME Tool Integration (fcitx/ibus)
--- @module ime-auto.linux-ime-tool

local M = {}
local utils = require("ime-auto.utils")

local SLOT_DIR = vim.fn.stdpath("data") .. "/ime-auto"
local ENGINE_ID_PATTERN = "^[%w%.%-_:]+$"
local SLOT_NAME_PATTERN = "^[a-zA-Z0-9_-]+$"

local FALLBACK_ENGINE = {
  fcitx = "keyboard-us",
  ibus = "xkb:us::eng",
}

local detected_tool = nil

local function run_command(cmd)
  local result = vim.fn.system(cmd)
  return utils.trim(result), vim.v.shell_error == 0
end

function M.detect_tool()
  if detected_tool == nil then
    if vim.fn.executable("fcitx-remote") == 1 then
      detected_tool = "fcitx"
    elseif vim.fn.executable("ibus") == 1 then
      detected_tool = "ibus"
    else
      detected_tool = false
    end
  end
  return detected_tool or nil
end

function M.reset_tool_cache()
  detected_tool = nil
end

-- Testing hook: allows tests to isolate slot storage from real user data
function M.set_slot_dir(path)
  SLOT_DIR = path
end

function M.get_slot_dir()
  return SLOT_DIR
end

local function ensure_slot_dir()
  if vim.fn.isdirectory(SLOT_DIR) == 0 then
    vim.fn.mkdir(SLOT_DIR, "p")
  end
  vim.fn.setfperm(SLOT_DIR, "rwx------")
end

local function slot_path(slot)
  if not slot or not slot:match(SLOT_NAME_PATTERN) then
    return nil
  end
  return SLOT_DIR .. "/saved-ime-" .. slot .. ".txt"
end

local function write_slot(slot, value)
  local path = slot_path(slot)
  if not path or not value then return false end

  ensure_slot_dir()
  if vim.fn.writefile({ value }, path) ~= 0 then
    return false
  end
  vim.fn.setfperm(path, "rw-------")
  return true
end

local function read_slot(slot)
  local path = slot_path(slot)
  if not path or vim.fn.filereadable(path) == 0 then
    return nil
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines[1] then return nil end
  return utils.trim(lines[1])
end

function M.get_current()
  local tool = M.detect_tool()
  if tool == "fcitx" then
    local result, ok = run_command("fcitx-remote -n")
    return (ok and result ~= "") and result or nil
  elseif tool == "ibus" then
    local result, ok = run_command("ibus engine")
    return (ok and result ~= "") and result or nil
  end
  return nil
end

function M.switch_to(engine_id)
  if not engine_id or type(engine_id) ~= "string" or not engine_id:match(ENGINE_ID_PATTERN) then
    vim.notify("[ime-auto] Invalid IME engine ID format: " .. tostring(engine_id), vim.log.levels.ERROR)
    return false
  end

  local tool = M.detect_tool()
  if tool == "fcitx" then
    local _, ok = run_command("fcitx-remote -s " .. vim.fn.shellescape(engine_id))
    return ok
  elseif tool == "ibus" then
    local _, ok = run_command("ibus engine " .. vim.fn.shellescape(engine_id))
    return ok
  end
  return false
end

function M.is_active()
  local tool = M.detect_tool()
  if tool == "fcitx" then
    local result, ok = run_command("fcitx-remote")
    return ok and result == "2"
  elseif tool == "ibus" then
    local current = M.get_current()
    return current ~= nil and current:match("mozc") ~= nil
  end
  return nil
end

function M.save_insert_ime()
  local current = M.get_current()
  return current ~= nil and write_slot("a", current)
end

function M.save_normal_ime()
  local current = M.get_current()
  return current ~= nil and write_slot("b", current)
end

function M.toggle_from_insert()
  local current = M.get_current()
  if not current then return false end
  write_slot("a", current)

  local target = read_slot("b") or FALLBACK_ENGINE[M.detect_tool()]
  if not target then return false end
  return M.switch_to(target)
end

function M.toggle_from_normal()
  local current = M.get_current()
  if not current then return false end
  write_slot("b", current)

  local target = read_slot("a")
  if not target then return true end
  return M.switch_to(target)
end

return M
