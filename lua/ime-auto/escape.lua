local M = {}

local pending_char = nil
local pending_pos = nil
local timer = nil

local function clear_pending()
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end
  pending_char = nil
  pending_pos = nil
end

local function expected_pos_after_pending()
  if not pending_char or not pending_pos then
    return nil
  end
  return { pending_pos[1], pending_pos[2] + vim.fn.strlen(pending_char) }
end

local function is_at_expected_pos()
  local expected = expected_pos_after_pending()
  if not expected then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] == expected[1] and cursor[2] == expected[2]
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

function M.on_cursor_moved_i()
  if not pending_char then
    return
  end

  if not is_at_expected_pos() then
    clear_pending()
  end
end

function M.on_insert_char_pre()
  local char = vim.v.char
  local config = require("ime-auto.config").get()

  if not char or char == "" then
    return
  end

  local escape_seq = config.escape_sequence
  local first_char = vim.fn.strcharpart(escape_seq, 0, 1)
  local second_char = vim.fn.strcharpart(escape_seq, 1, 1)

  if pending_char == first_char and char == second_char and is_at_expected_pos() then
    clear_pending()

    vim.schedule(function()
      handle_escape_sequence()
    end)
  elseif char == first_char then
    clear_pending()

    pending_char = char
    pending_pos = vim.api.nvim_win_get_cursor(0)
    timer = vim.fn.timer_start(config.escape_timeout, function()
      clear_pending()
    end)
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
