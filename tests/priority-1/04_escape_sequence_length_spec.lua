-- tests/priority-1/04_escape_sequence_length_spec.lua
-- Test 04: Escape sequence of arbitrary length (1, 2, 3+ chars)

local ime_auto = require("ime-auto")
local escape = require("ime-auto.escape")
local ime = require("ime-auto.ime")

-- Simulates InsertCharPre firing for each char, then the actual buffer
-- insertion that Neovim would normally perform right after the event.
local function type_chars(chars)
  for _, char in ipairs(chars) do
    vim.v.char = char
    escape.on_insert_char_pre()

    local line = vim.api.nvim_get_current_line()
    local new_line = line .. char
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { 1, vim.fn.strlen(new_line) })
  end
end

describe("Test 04: Escape sequence arbitrary length", function()
  local original_save_state = nil

  before_each(function()
    vim.cmd("enew!")
    vim.cmd("only")
    vim.opt.encoding = "utf-8"
    vim.opt.fileencoding = "utf-8"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
    -- Headless Neovim never reports mode() == "i", but entering insert
    -- mode is still required so the cursor isn't clamped to the last
    -- character boundary the way it would be in Normal mode.
    vim.cmd("startinsert")
    vim.wait(20)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    -- Avoid touching the real OS IME during unit tests
    original_save_state = ime.save_state
    ime.save_state = function() end
  end)

  after_each(function()
    ime.save_state = original_save_state
    pcall(vim.cmd, "bdelete!")
  end)

  describe("4.1: Single character escape_sequence", function()
    before_each(function()
      ime_auto.setup({ escape_sequence = "ｋ", escape_timeout = 200, debug = false })
    end)

    it("should trigger escape immediately on the single char", function()
      type_chars({ "ｋ" })
      vim.wait(50)

      assert.equals("", vim.api.nvim_get_current_line())
    end)
  end)

  describe("4.2: Two character escape_sequence", function()
    before_each(function()
      ime_auto.setup({ escape_sequence = "ｋｊ", escape_timeout = 200, debug = false })
    end)

    it("should trigger escape after both chars typed in order", function()
      type_chars({ "ｋ", "ｊ" })
      vim.wait(50)

      assert.equals("", vim.api.nvim_get_current_line())
    end)

    it("should not trigger when only the first char is typed", function()
      type_chars({ "ｋ" })
      vim.wait(250)

      assert.equals("ｋ", vim.api.nvim_get_current_line())
    end)
  end)

  describe("4.3: Three character escape_sequence", function()
    before_each(function()
      ime_auto.setup({ escape_sequence = "ｋｊｊ", escape_timeout = 200, debug = false })
    end)

    it("should trigger escape only after all three chars typed in order", function()
      type_chars({ "ｋ", "ｊ", "ｊ" })
      vim.wait(50)

      assert.equals("", vim.api.nvim_get_current_line())
    end)

    it("should not trigger with only two of the three chars", function()
      type_chars({ "ｋ", "ｊ" })
      vim.wait(250)

      assert.equals("ｋｊ", vim.api.nvim_get_current_line())
    end)

    it("should not trigger when a wrong char breaks the sequence", function()
      type_chars({ "ｋ", "x", "ｊ" })
      vim.wait(50)

      assert.equals("ｋxｊ", vim.api.nvim_get_current_line())
    end)

    it("should restart matching when the wrong char equals the first char", function()
      type_chars({ "ｋ", "ｋ", "ｊ", "ｊ" })
      vim.wait(50)

      assert.equals("ｋ", vim.api.nvim_get_current_line())
    end)
  end)
end)
