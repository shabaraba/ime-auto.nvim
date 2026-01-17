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

  M.utils.create_user_command("ListInputSources", function()
    local result, err = M.ime.list_input_sources()
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.WARN)
      return
    end

    if result then
      -- Display in a new buffer
      local buf = vim.api.nvim_create_buf(false, true)
      local lines = vim.split(result, "\n")

      -- Add header
      local header = {
        "=== Available Input Sources ===",
        "",
        "Copy the ID (e.g., 'com.apple.keylayout.ABC') and use it in your config:",
        "",
        "require('ime-auto').setup({",
        "  macos_input_source_en = 'com.apple.keylayout.ABC',",
        "  macos_input_source_ja = 'com.google.inputmethod.Japanese.base',",
        "})",
        "",
        "---",
        "",
      }

      for i = #header, 1, -1 do
        table.insert(lines, 1, header[i])
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
      vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
      vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

      -- Open in a split
      vim.cmd('split')
      vim.api.nvim_win_set_buf(0, buf)
    else
      vim.notify("[ime-auto] Failed to list input sources", vim.log.levels.ERROR)
    end
  end, { desc = "List available input sources (macOS only)" })

  M.utils.create_user_command("SelectEnglishInput", function()
    local sources, err = M.ime.parse_input_sources()
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.WARN)
      return
    end

    if not sources or #sources == 0 then
      vim.notify("[ime-auto] No input sources found", vim.log.levels.ERROR)
      return
    end

    -- Create display items
    local items = {}
    for _, source in ipairs(sources) do
      table.insert(items, source.name)
    end

    vim.ui.select(items, {
      prompt = "Select English input source:",
    }, function(choice, idx)
      if choice and idx then
        local selected = sources[idx]
        M.config.set_input_source_en(selected.id)
        vim.notify(string.format("[ime-auto] English input set to: %s", selected.id), vim.log.levels.INFO)
      end
    end)
  end, { desc = "Select English input source interactively (macOS only)" })

  M.utils.create_user_command("SelectJapaneseInput", function()
    local config_opts = M.config.get()
    if config_opts.macos_ime_tool == "macime" then
      vim.notify("[ime-auto] macime doesn't require Japanese input source configuration.\nIt automatically saves and restores your Japanese IME.", vim.log.levels.INFO)
      return
    end

    local sources, err = M.ime.parse_input_sources()
    if err then
      vim.notify("[ime-auto] " .. err, vim.log.levels.WARN)
      return
    end

    if not sources or #sources == 0 then
      vim.notify("[ime-auto] No input sources found", vim.log.levels.ERROR)
      return
    end

    -- Create display items
    local items = {}
    for _, source in ipairs(sources) do
      table.insert(items, source.name)
    end

    vim.ui.select(items, {
      prompt = "Select Japanese input source:",
    }, function(choice, idx)
      if choice and idx then
        local selected = sources[idx]
        M.config.set_input_source_ja(selected.id)
        vim.notify(string.format("[ime-auto] Japanese input set to: %s", selected.id), vim.log.levels.INFO)
      end
    end)
  end, { desc = "Select Japanese input source interactively (macOS only)" })
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