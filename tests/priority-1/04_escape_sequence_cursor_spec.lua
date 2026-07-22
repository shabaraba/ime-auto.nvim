-- tests/priority-1/04_escape_sequence_cursor_spec.lua
-- Test 04: Cursor position after escape sequence deletion (issue #22)

local ime_auto = require("ime-auto")
local escape = require("ime-auto.escape")
local ime = require("ime-auto.ime")

describe("Test 04: Cursor position after escape sequence deletion", function()
  local original_save_state = nil

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

    -- Headless tests can't enter real Insert mode, where the cursor is
    -- allowed one column past the last character. virtualedit=onemore
    -- reproduces that same allowance while staying in Normal mode.
    vim.wo.virtualedit = "onemore"

    original_save_state = ime.save_state
    ime.save_state = function() end
  end)

  after_each(function()
    ime.save_state = original_save_state
    vim.wo.virtualedit = ""
    vim.cmd("bdelete!")
  end)

  local function type_escape_sequence(line_before_seq, line_after_seq)
    local seq_first_byte_line = line_before_seq .. "ｋ" .. line_after_seq
    local col_after_first = vim.fn.strlen(line_before_seq .. "ｋ")

    vim.api.nvim_buf_set_lines(0, 0, -1, false, { line_before_seq .. line_after_seq })
    vim.api.nvim_win_set_cursor(0, { 1, vim.fn.strlen(line_before_seq) })

    vim.v.char = "ｋ"
    escape.on_insert_char_pre()

    vim.api.nvim_buf_set_lines(0, 0, -1, false, { seq_first_byte_line })
    vim.api.nvim_win_set_cursor(0, { 1, col_after_first })

    vim.v.char = "ｊ"
    escape.on_insert_char_pre()

    local final_line = line_before_seq .. "ｋｊ" .. line_after_seq
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { final_line })
    vim.api.nvim_win_set_cursor(0, { 1, vim.fn.strlen(line_before_seq .. "ｋｊ") })

    vim.wait(50)
  end

  describe("4.1: Escape sequence typed mid-line", function()
    it("should restore cursor right after the preceding character", function()
      type_escape_sequence("あいう", "えお")

      local line = vim.api.nvim_get_current_line()
      local cursor = vim.api.nvim_win_get_cursor(0)

      assert.equals("あいうえお", line)
      assert.equals(vim.fn.strlen("あいう"), cursor[2],
        "Cursor should stay right after 'う', not at end of line")
    end)
  end)

  describe("4.2: Escape sequence typed at end of line", function()
    it("should place cursor at end of line", function()
      type_escape_sequence("あいう", "")

      local line = vim.api.nvim_get_current_line()
      local cursor = vim.api.nvim_win_get_cursor(0)

      assert.equals("あいう", line)
      assert.equals(vim.fn.strlen("あいう"), cursor[2])
    end)
  end)

  describe("4.3: Escape sequence typed at start of line", function()
    it("should place cursor at start of line", function()
      type_escape_sequence("", "あいう")

      local line = vim.api.nvim_get_current_line()
      local cursor = vim.api.nvim_win_get_cursor(0)

      assert.equals("あいう", line)
      assert.equals(0, cursor[2])
    end)
  end)
end)
