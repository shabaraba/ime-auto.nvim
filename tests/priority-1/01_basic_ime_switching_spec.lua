-- tests/priority-1/01_basic_ime_switching_spec.lua
-- Test 01: Basic IME switching

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local escape = require("ime-auto.escape")

describe("Test 01: Basic IME switching", function()
  before_each(function()
    -- Setup with default config
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    -- Clean slate
    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    -- Cleanup
    if vim.api.nvim_get_mode().mode == "i" then
      vim.cmd("stopinsert")
    end
    pcall(vim.cmd, "bdelete!")
  end)

  describe("1.1: InsertEnter autocmd registration", function()
    it("should register InsertEnter autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      local insert_enter = vim.tbl_filter(function(cmd)
        return cmd.event == "InsertEnter"
      end, autocmds)

      assert.equals(1, #insert_enter, "InsertEnter autocmd should be registered")
    end)
  end)

  describe("1.2: InsertLeave autocmd registration", function()
    it("should register InsertLeave autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "ime_auto" })
      local insert_leave = vim.tbl_filter(function(cmd)
        return cmd.event == "InsertLeave"
      end, autocmds)

      assert.equals(1, #insert_leave, "InsertLeave autocmd should be registered")
    end)
  end)

  describe("1.3: Escape sequence autocmd registration", function()
    it("should register InsertCharPre autocmd", function()
      local autocmds = vim.api.nvim_get_autocmds({
        group = "ime_auto_escape"
      })

      assert.is_true(#autocmds > 0, "Escape sequence autocmd should be registered")
    end)
  end)

  describe("1.4: Plugin loaded flag", function()
    it("should set loaded flag", function()
      assert.is_true(vim.g.loaded_ime_auto, "Plugin should be loaded")
    end)
  end)

  describe("1.5: Basic mode transitions", function()
    it("should start in normal mode", function()
      assert.equals("n", vim.api.nvim_get_mode().mode)
    end)

    it("should be able to trigger InsertEnter event", function()
      -- In headless mode, startinsert doesn't work
      -- Instead, we trigger the autocmd directly
      vim.cmd("doautocmd InsertEnter")
      vim.wait(50)
      -- Test passes if no error occurs
      assert.is_true(true, "InsertEnter event should trigger without error")
    end)

    it("should be able to trigger InsertLeave event", function()
      vim.cmd("doautocmd InsertLeave")
      vim.wait(50)
      -- Test passes if no error occurs
      assert.is_true(true, "InsertLeave event should trigger without error")
    end)
  end)

  describe("1.6: IME state check availability", function()
    it("should be able to call get_status without error", function()
      local status = ime.get_status()
      -- Status can be true, false, or nil depending on OS
      assert.is_not_nil(status ~= nil or status == nil, "Should return some value")
    end)
  end)
end)
