-- tests/priority-1/04_disable_escape_sequence_spec.lua
-- Test 04: Escape sequence handling is stopped by ImeAutoDisable

local ime_auto = require("ime-auto")
local escape = require("ime-auto.escape")

-- Simulates real Insert-mode typing of "ｋｊ": fires InsertCharPre for each
-- character and only inserts it into the buffer if InsertCharPre didn't
-- cancel it (v:char == ""). A full match cancels the final character to
-- shrink the race window, so it never actually lands in the buffer.
local function type_escape_sequence()
  for _, char in ipairs({ "ｋ", "ｊ" }) do
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()

    vim.v.char = char
    escape.on_insert_char_pre()

    if vim.v.char ~= "" then
      local new_line = vim.fn.strpart(line, 0, cursor[2]) .. char .. vim.fn.strpart(line, cursor[2])
      vim.api.nvim_buf_set_lines(0, cursor[1] - 1, cursor[1], false, { new_line })
      vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + vim.fn.strlen(char) })
    end
  end

  vim.wait(50)
end

describe("Test 04: Disable stops escape sequence handling", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
    vim.opt.virtualedit = "onemore"
  end)

  after_each(function()
    ime_auto.enable()
    vim.opt.virtualedit = ""
    pcall(vim.cmd, "bdelete!")
  end)

  describe("4.1: on_insert_char_pre no-op while disabled", function()
    it("should not modify the buffer when disabled", function()
      ime_auto.disable()

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, vim.fn.strlen("test") })

      type_escape_sequence()

      local result = vim.api.nvim_get_current_line()
      assert.equals("testｋｊ", result, "Buffer should be untouched while disabled")
    end)

    it("should keep escape.enabled in sync with plugin state", function()
      ime_auto.disable()
      assert.is_false(escape.enabled, "escape.enabled should be false after disable")

      ime_auto.enable()
      assert.is_true(escape.enabled, "escape.enabled should be true after enable")
    end)
  end)

  describe("4.2: Escape sequence works again after re-enable", function()
    it("should delete the sequence once re-enabled", function()
      ime_auto.disable()
      ime_auto.enable()

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })
      vim.api.nvim_win_set_cursor(0, { 1, vim.fn.strlen("test") })

      type_escape_sequence()

      local result = vim.api.nvim_get_current_line()
      assert.equals("test", result, "Buffer should have the escape sequence removed once enabled")
    end)
  end)
end)
