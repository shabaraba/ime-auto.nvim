-- tests/priority-1/03_multibyte_char_boundaries_spec.lua
-- Test 03: Multibyte character boundaries

local ime_auto = require("ime-auto")

describe("Test 03: Multibyte character boundaries", function()
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
  end)

  after_each(function()
    vim.cmd("bdelete!")
  end)

  describe("3.1: Byte vs Character length calculations", function()
    it("should correctly calculate byte and character lengths", function()
      local test_cases = {
        { str = "あいう", bytes = 9, chars = 3 },
        { str = "😀🎉", bytes = 8, chars = 2 },
        { str = "ABC", bytes = 3, chars = 3 },
      }

      for _, test in ipairs(test_cases) do
        local byte_len = vim.fn.strlen(test.str)
        local char_len = vim.fn.strchars(test.str)

        assert.equals(test.bytes, byte_len,
          string.format("Byte length for '%s'", test.str))
        assert.equals(test.chars, char_len,
          string.format("Char length for '%s'", test.str))
      end
    end)
  end)

  describe("3.2: strpart vs strcharpart", function()
    it("should correctly extract substrings by bytes", function()
      local str = "あいう"
      -- First character is 3 bytes
      local byte_part = vim.fn.strpart(str, 0, 3)
      assert.equals("あ", byte_part)
    end)

    it("should correctly extract substrings by characters", function()
      local str = "あいう😀test"
      -- First 3 characters
      local char_part = vim.fn.strcharpart(str, 0, 3)
      assert.equals("あいう", char_part)
    end)
  end)

  describe("3.3: Cursor position with multibyte characters", function()
    it("should handle hiragana characters", function()
      -- Set buffer content
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "あいう" })

      -- Move cursor to end (Neovim auto-adjusts to character boundary)
      -- Attempting to set position 9, but Neovim adjusts to last char start (byte 6)
      vim.api.nvim_win_set_cursor(0, {1, 9})

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(6, cursor[2], "Cursor adjusted to last char boundary at byte 6")
    end)

    it("should handle emoji characters", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "😀🎉" })

      -- Move cursor to end (2 emojis: 😀=4 bytes, 🎉=4 bytes)
      -- Attempting byte 8, but Neovim adjusts to last char start (byte 4)
      vim.api.nvim_win_set_cursor(0, {1, 8})

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(4, cursor[2], "Cursor adjusted to last char boundary at byte 4")
    end)

    it("should handle mixed content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ABC あいう 😀" })

      -- ABC=3, space=1, あいう=9, space=1, 😀=4 = 18 bytes total
      -- Attempting byte 18, Neovim adjusts to last char start (byte 14)
      vim.api.nvim_win_set_cursor(0, {1, 18})

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(14, cursor[2], "Cursor adjusted to last char boundary")
    end)
  end)

  describe("3.4: Character boundary detection", function()
    it("should detect character at cursor position", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "あいう" })

      -- Get character at position 0
      local line = vim.api.nvim_get_current_line()
      local first_char = vim.fn.strcharpart(line, 0, 1)

      assert.equals("あ", first_char)
    end)

    it("should handle character extraction from mixed content", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "testあいう" })

      local line = vim.api.nvim_get_current_line()

      -- Character 4 (0-indexed) should be "あ"
      local char_at_4 = vim.fn.strcharpart(line, 4, 1)
      assert.equals("あ", char_at_4)
    end)
  end)

  describe("3.5: Buffer content manipulation", function()
    it("should correctly append multibyte characters", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "test" })

      -- Append hiragana
      local line = vim.api.nvim_get_current_line()
      local new_line = line .. "あいう"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { new_line })

      local result = vim.api.nvim_get_current_line()
      assert.equals("testあいう", result)
      assert.equals(13, vim.fn.strlen(result)) -- 4 + 9 bytes
    end)

    it("should correctly delete multibyte characters", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "testｋｊ" })

      local line = vim.api.nvim_get_current_line()
      local line_chars = vim.fn.strchars(line)

      -- Remove last 2 characters (ｋｊ)
      local new_line = vim.fn.strcharpart(line, 0, line_chars - 2)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { new_line })

      local result = vim.api.nvim_get_current_line()
      assert.equals("test", result)
    end)
  end)

  describe("3.6: Edge cases", function()
    it("should handle empty string", function()
      assert.equals(0, vim.fn.strlen(""))
      assert.equals(0, vim.fn.strchars(""))
    end)

    it("should handle single multibyte character", function()
      local char = "あ"
      assert.equals(3, vim.fn.strlen(char))
      assert.equals(1, vim.fn.strchars(char))
    end)

    it("should handle line start position", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "あいう" })
      vim.api.nvim_win_set_cursor(0, {1, 0})

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(0, cursor[2])
    end)
  end)
end)
