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

--- Removes the already-inserted prefix of the escape sequence and finalizes
--- the mode switch. Runs on vim.schedule since buffer edits are disallowed
--- synchronously inside InsertCharPre (E565). `context` snapshots the
--- buffer/cursor/changedtick at detection time so that any input arriving
--- before this callback runs (IME multi-char commit, macro playback, ...)
--- is detected as a race instead of silently corrupting the buffer.
local function finalize_escape_sequence(context)
  local utils = require("ime-auto.utils")

  if vim.api.nvim_get_current_buf() ~= context.bufnr then
    utils.notify("Escape sequence aborted: buffer changed before removal", vim.log.levels.WARN)
    return false
  end

  if vim.api.nvim_buf_get_changedtick(context.bufnr) ~= context.changedtick then
    utils.notify(
      "Escape sequence aborted: additional input arrived before removal (possible race)",
      vim.log.levels.WARN
    )
    return false
  end

  local line = vim.api.nvim_buf_get_lines(context.bufnr, context.row, context.row + 1, false)[1] or ""
  local col = context.col
  local prefix_len = vim.fn.strlen(context.already_inserted)

  if prefix_len > 0
      and (col < prefix_len or vim.fn.strpart(line, col - prefix_len, prefix_len) ~= context.already_inserted) then
    utils.notify("Escape sequence aborted: unexpected buffer content before removal", vim.log.levels.WARN)
    return false
  end

  local new_col = col - prefix_len
  local new_line = vim.fn.strpart(line, 0, new_col) .. vim.fn.strpart(line, col)
  vim.api.nvim_buf_set_lines(context.bufnr, context.row, context.row + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { context.row + 1, new_col })

  require("ime-auto.ime").save_state()
  vim.cmd("stopinsert")

  utils.notify("Escape sequence detected", vim.log.levels.DEBUG)

  return true
end

local function advance_match(count, escape_timeout)
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
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
  local at_valid_pos = matched_count == 0 or is_at_expected_pos()

  if char == expected_char and at_valid_pos and matched_count + 1 >= seq_len then
    -- Full match. Cancel insertion of this final character immediately so
    -- the escape sequence never fully lands in the buffer; only the
    -- already-inserted prefix (matched_count chars) needs a deferred
    -- removal, shrinking the race window down to "one verification".
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local context = {
      bufnr = bufnr,
      changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
      row = cursor[1] - 1,
      col = cursor[2],
      already_inserted = vim.fn.strcharpart(escape_seq, 0, matched_count),
    }

    clear_pending()
    vim.v.char = ""

    vim.schedule(function()
      finalize_escape_sequence(context)
    end)
  elseif char == expected_char and at_valid_pos then
    advance_match(matched_count + 1, config.escape_timeout)
  elseif char == first_char then
    advance_match(1, config.escape_timeout)
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
