local M = {}

local pending_char = nil
local timer = nil

local function clear_pending()
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end
  pending_char = nil
end

--- Removes the already-inserted first_char and finalizes the escape
--- sequence. Runs on vim.schedule since buffer edits are disallowed
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
  local first_char_len = vim.fn.strlen(context.first_char)

  if col < first_char_len or vim.fn.strpart(line, col - first_char_len, first_char_len) ~= context.first_char then
    utils.notify("Escape sequence aborted: unexpected buffer content before removal", vim.log.levels.WARN)
    return false
  end

  local new_line = vim.fn.strpart(line, 0, col - first_char_len) .. vim.fn.strpart(line, col)
  vim.api.nvim_buf_set_lines(context.bufnr, context.row, context.row + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { context.row + 1, col - first_char_len })

  require("ime-auto.ime").save_state()
  vim.cmd("stopinsert")

  utils.notify("Escape sequence detected", vim.log.levels.DEBUG)

  return true
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

  if pending_char == first_char and char == second_char then
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local context = {
      bufnr = bufnr,
      changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
      row = cursor[1] - 1,
      col = cursor[2],
      first_char = first_char,
    }

    clear_pending()

    -- Cancel insertion of the second character immediately so the escape
    -- sequence never fully lands in the buffer. Only the already-inserted
    -- first_char needs a deferred removal, shrinking the race window from
    -- "two characters to match" down to "one character to verify".
    vim.v.char = ""

    vim.schedule(function()
      finalize_escape_sequence(context)
    end)
  elseif char == first_char then
    clear_pending()

    pending_char = char
    timer = vim.fn.timer_start(config.escape_timeout, function()
      clear_pending()
    end)
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