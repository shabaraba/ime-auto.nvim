local M = {}

function M.is_insert_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "i" or mode == "ic" or mode == "ix"
end

function M.is_normal_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "n"
end

function M.is_visual_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "v" or mode == "V" or mode == "^V" or mode:match("^[vV\22]")
end

function M.is_command_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode == "c" or mode == "cv" or mode == "ce"
end

function M.notify(msg, level)
  local config = require("ime-auto.config").get()
  if config.debug or level >= vim.log.levels.WARN then
    vim.notify("[ime-auto] " .. msg, level or vim.log.levels.INFO)
  end
end

function M.create_user_command(name, func, opts)
  vim.api.nvim_create_user_command("ImeAuto" .. name, func, opts or {})
end

function M.trim(str)
  if not str then return nil end
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

return M