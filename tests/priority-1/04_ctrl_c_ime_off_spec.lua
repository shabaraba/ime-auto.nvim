-- tests/priority-1/04_ctrl_c_ime_off_spec.lua
-- Test 04: IME off when leaving Insert mode via <C-c>

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 04: Ctrl-C leaves Insert mode and turns IME off", function()
  local original_control = nil
  local off_call_count = 0

  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")

    off_call_count = 0
    original_control = ime.control
    ime.control = function(action)
      if action == "off" then
        off_call_count = off_call_count + 1
      end
      return original_control(action)
    end
  end)

  after_each(function()
    if vim.api.nvim_get_mode().mode == "i" then
      vim.cmd("stopinsert")
    end
    pcall(vim.cmd, "bdelete!")

    if original_control then
      ime.control = original_control
    end
  end)

  describe("4.1: ModeChanged autocmd registration", function()
    it("should register a ModeChanged autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      local mode_changed = vim.tbl_filter(function(cmd)
        return cmd.event == "ModeChanged" and cmd.pattern == "*:n"
      end, autocmds)

      assert.is_true(#mode_changed > 0, "ModeChanged autocmd should be registered")
    end)
  end)

  describe("4.2: Leaving Insert mode via <C-c>", function()
    it("should turn IME off even though InsertLeave does not fire", function()
      local keys = vim.api.nvim_replace_termcodes("i<C-c>", true, false, true)
      vim.api.nvim_feedkeys(keys, "x", false)
      vim.wait(50)

      assert.equals("n", vim.api.nvim_get_mode().mode)
      assert.is_true(off_call_count > 0, "IME off should be called after <C-c>")
    end)
  end)

  describe("4.3: Leaving Insert mode via <Esc> should not double-fire", function()
    it("should call IME off exactly once", function()
      local keys = vim.api.nvim_replace_termcodes("ihello<Esc>", true, false, true)
      vim.api.nvim_feedkeys(keys, "x", false)
      vim.wait(50)

      assert.equals("n", vim.api.nvim_get_mode().mode)
      assert.equals(1, off_call_count, "IME off should be called exactly once for <Esc>")
    end)
  end)

  describe("4.4: Repeated Ctrl-C and Esc sequences stay consistent", function()
    it("should keep calling IME off exactly once per leave", function()
      for _ = 1, 3 do
        off_call_count = 0
        local esc_keys = vim.api.nvim_replace_termcodes("i<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc_keys, "x", false)
        vim.wait(30)
        assert.equals(1, off_call_count, "Esc leave should call IME off exactly once")

        off_call_count = 0
        local ctrl_c_keys = vim.api.nvim_replace_termcodes("i<C-c>", true, false, true)
        vim.api.nvim_feedkeys(ctrl_c_keys, "x", false)
        vim.wait(30)
        assert.equals(1, off_call_count, "Ctrl-C leave should call IME off exactly once")
      end
    end)
  end)
end)
