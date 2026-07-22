-- tests/priority-1/04_pending_char_cursor_reset_spec.lua
-- Test 04: pending_char reset on cursor movement (issue #26)

local ime_auto = require("ime-auto")
local escape = require("ime-auto.escape")

-- Simulates what Neovim does for a real keystroke in insert mode:
-- fire InsertCharPre (before insertion), insert the character, then
-- fire CursorMovedI now that the cursor has advanced.
local function type_char(char)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()

  vim.v.char = char
  escape.on_insert_char_pre()

  local new_line = vim.fn.strpart(line, 0, cursor[2]) .. char .. vim.fn.strpart(line, cursor[2])
  vim.api.nvim_buf_set_lines(0, cursor[1] - 1, cursor[1], false, { new_line })
  vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + vim.fn.strlen(char) })

  escape.on_cursor_moved_i()
end

-- Simulates the cursor being moved away from where it naturally would be
-- (e.g. arrow keys, mouse click) and firing CursorMovedI as Neovim would.
local function move_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
  escape.on_cursor_moved_i()
end

describe("Test 04: pending_char cursor reset", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
    vim.opt.encoding = "utf-8"
    vim.opt.fileencoding = "utf-8"
    vim.cmd("startinsert!")
  end)

  after_each(function()
    escape.teardown()
    escape.setup()
    vim.cmd("bdelete!")
  end)

  describe("4.1: Continuous typing at the same position", function()
    it("should still trigger the escape sequence", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      type_char("ｋ")
      type_char("ｊ")
      vim.wait(50)

      assert.equals("test", vim.api.nvim_get_current_line(),
        "Escape sequence should be removed when typed continuously")
    end)
  end)

  describe("4.2: Cursor jumps away and back before the second char", function()
    it("should not trigger since the jump broke position continuity", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      type_char("ｋ") -- buffer: "testｋ", cursor at col 7

      move_cursor(1, 0) -- jump away, should clear pending_char
      move_cursor(1, 7) -- jump back to the same spot

      type_char("ｊ")
      vim.wait(50)

      assert.equals("testｋｊ", vim.api.nvim_get_current_line(),
        "Escape sequence should NOT trigger once the cursor jump broke continuity")
    end)
  end)

  describe("4.3: Second char typed near pre-existing matching text", function()
    it("should not trigger based on unrelated buffer content", function()
      -- Pre-existing "ｋ" earlier in the line, unrelated to the char about to be typed
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ｋtest" })
      local end_col = vim.fn.strlen("ｋtest")
      vim.api.nvim_win_set_cursor(0, { 1, end_col })

      type_char("ｋ") -- buffer: "ｋtestｋ"

      -- User moves the cursor back to just after the pre-existing leading "ｋ"
      move_cursor(1, vim.fn.strlen("ｋ"))

      type_char("ｊ")
      vim.wait(50)

      assert.equals("ｋｊtestｋ", vim.api.nvim_get_current_line(),
        "Escape sequence should not fire from coincidental matching text elsewhere in the buffer")
    end)
  end)

  describe("4.4: Timeout still clears pending_char", function()
    it("should reset after escape_timeout elapses without a second char", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      type_char("ｋ")
      vim.wait(300) -- exceeds escape_timeout (200ms)

      type_char("ｊ")
      vim.wait(50)

      assert.equals("testｋｊ", vim.api.nvim_get_current_line(),
        "Escape sequence should not fire after timeout")
    end)
  end)
end)
