local M = {}

M.config = require("ime-auto.config")
M.ime = require("ime-auto.ime")
M.escape = require("ime-auto.escape")
M.utils = require("ime-auto.utils")

local enabled = false

local function create_autocmds()
  local group = vim.api.nvim_create_augroup("ime_auto", { clear = true })
  
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      if enabled then
        M.ime.restore_state()
        M.utils.notify("Restored IME state", vim.log.levels.DEBUG)
      end
    end,
  })
  
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      if enabled then
        M.ime.save_state()
        M.ime.off()
        M.utils.notify("IME turned off", vim.log.levels.DEBUG)
      end
    end,
  })
  
  vim.api.nvim_create_autocmd({"ModeChanged"}, {
    group = group,
    pattern = {"*:[nvV\22]", "*:c"},
    callback = function()
      if enabled then
        M.ime.off()
        M.utils.notify("IME turned off (mode change)", vim.log.levels.DEBUG)
      end
    end,
  })
end

local function create_commands()
  M.utils.create_user_command("Enable", function()
    M.enable()
  end, { desc = "Enable IME auto switching" })
  
  M.utils.create_user_command("Disable", function()
    M.disable()
  end, { desc = "Disable IME auto switching" })
  
  M.utils.create_user_command("Toggle", function()
    M.toggle()
  end, { desc = "Toggle IME auto switching" })
  
  M.utils.create_user_command("Status", function()
    local status = enabled and "enabled" or "disabled"
    local ime_status = M.ime.get_status() and "on" or "off"
    vim.notify(string.format("ime-auto: %s, IME: %s", status, ime_status))
  end, { desc = "Show IME auto status" })
end

function M.setup(opts)
  M.config.setup(opts)
  
  create_autocmds()
  create_commands()
  
  M.escape.setup()
  
  M.enable()
  
  M.utils.notify("Setup complete", vim.log.levels.DEBUG)
end

function M.enable()
  enabled = true
  if M.utils.is_normal_mode() then
    M.ime.off()
  end
  M.utils.notify("Enabled", vim.log.levels.INFO)
end

function M.disable()
  enabled = false
  M.utils.notify("Disabled", vim.log.levels.INFO)
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.is_enabled()
  return enabled
end

return M