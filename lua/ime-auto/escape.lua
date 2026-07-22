local M = {}

M.enabled = true

local matched_count = 0
local match_start_pos = nil
local timer = nil

local function clear_pending()
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end
  matched_count = 0
  match_start_pos = nil
end

local function is_at_expected_pos()
  if not match_start_pos then
    return false
  end
  local config = require("ime-auto.config").get()
  local matched_bytes = vim.fn.strlen(vim.fn.strcharpart(config.escape_sequence, 0, matched_count))
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] == match_start_pos[1] and cursor[2] == match_start_pos[2] + matched_bytes
end

local function handle_escape_sequence()
  local config = require("ime-auto.config").get()
  local ime = require("ime-auto.ime")

  clear_pending()

  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  local escape_seq = config.escape_sequence
  local seq_len = vim.fn.strchars(escape_seq)

  if col >= seq_len then
    local before_cursor = vim.fn.strpart(line, 0, col)
    local last_chars = vim.fn.strcharpart(before_cursor, vim.fn.strchars(before_cursor) - seq_len)

    if last_chars == escape_seq then
      local new_col = col - vim.fn.strlen(escape_seq)
      local new_line = vim.fn.strpart(line, 0, new_col) .. vim.fn.strpart(line, col)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, new_col })

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
    match_start_pos = nil
    vim.schedule(function()
      handle_escape_sequence()
    end)
    return
  end

  if count == 1 then
    local cursor = vim.api.nvim_win_get_cursor(0)
    match_start_pos = { cursor[1], cursor[2] }
  end

  matched_count = count
  timer = vim.fn.timer_start(escape_timeout, clear_pending)
end

function M.on_cursor_moved_i()
  if matched_count > 0 and not is_at_expected_pos() then
    clear_pending()
  end
end

function M.on_insert_char_pre()
  if not M.enabled then
    return
  end

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

  if char == expected_char and (matched_count == 0 or is_at_expected_pos()) then
    advance_match(matched_count + 1, seq_len, config.escape_timeout)
  elseif char == first_char then
    advance_match(1, seq_len, config.escape_timeout)
  else
    clear_pending()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ime_auto_escape", { clear = true })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    callback = M.on_insert_char_pre,
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = group,
    callback = M.on_cursor_moved_i,
  })
end

function M.teardown()
  clear_pending()
  vim.api.nvim_del_augroup_by_name("ime_auto_escape")
end

return M
