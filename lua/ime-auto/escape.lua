local M = {}

local matched_count = 0
local timer = nil

local function clear_pending()
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end
  matched_count = 0
end

local function handle_escape_sequence()
  local config = require("ime-auto.config").get()
  local ime = require("ime-auto.ime")

  clear_pending()

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  local escape_seq = config.escape_sequence
  local seq_len = vim.fn.strchars(escape_seq)

  if col >= seq_len then
    local before_cursor = vim.fn.strpart(line, 0, col)
    local last_chars = vim.fn.strcharpart(before_cursor, vim.fn.strchars(before_cursor) - seq_len)

    if last_chars == escape_seq then
      local new_line = vim.fn.strpart(line, 0, col - vim.fn.strlen(escape_seq)) .. vim.fn.strpart(line, col)
      vim.api.nvim_set_current_line(new_line)

      ime.save_state()

      vim.cmd("stopinsert")

      if config.debug then
        vim.notify("[ime-auto] Escape sequence detected", vim.log.levels.DEBUG)
      end

      return true
    end
  end

  return false
end

local function advance_match(count, seq_len, escape_timeout)
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end

  if count >= seq_len then
    matched_count = 0
    vim.schedule(function()
      handle_escape_sequence()
    end)
    return
  end

  matched_count = count
  timer = vim.fn.timer_start(escape_timeout, clear_pending)
end

function M.on_insert_char_pre()
  local char = vim.v.char

  if not char or char == "" then
    return
  end

  local config = require("ime-auto.config").get()
  local escape_seq = config.escape_sequence
  local seq_len = vim.fn.strchars(escape_seq)

  if seq_len == 0 then
    return
  end

  local expected_char = vim.fn.strcharpart(escape_seq, matched_count, 1)
  local first_char = vim.fn.strcharpart(escape_seq, 0, 1)

  if char == expected_char then
    advance_match(matched_count + 1, seq_len, config.escape_timeout)
  elseif char == first_char then
    advance_match(1, seq_len, config.escape_timeout)
  else
    clear_pending()
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = vim.api.nvim_create_augroup("ime_auto_escape", { clear = true }),
    callback = M.on_insert_char_pre,
  })
end

function M.teardown()
  clear_pending()
  vim.api.nvim_del_augroup_by_name("ime_auto_escape")
end

return M
