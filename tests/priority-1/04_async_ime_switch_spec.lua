-- tests/priority-1/04_async_ime_switch_spec.lua
-- Test 04: Asynchronous IME switching (issue #13)

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local swift_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: Asynchronous IME switching", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")
  end)

  after_each(function()
    pcall(vim.cmd, "bdelete!")
  end)

  describe("4.1: Dead debounce functions removed", function()
    it("should not expose off_debounced anymore", function()
      assert.is_nil(ime.off_debounced)
    end)

    it("should not expose on_debounced anymore", function()
      assert.is_nil(ime.on_debounced)
    end)
  end)

  describe("4.2: Swift tool invocations do not block the caller", function()
    it("toggle_from_insert should return before the subprocess completes", function()
      local start = vim.loop.hrtime()
      swift_tool.toggle_from_insert()
      local elapsed_ms = (vim.loop.hrtime() - start) / 1e6

      -- The Swift binary itself takes 50-260ms to finish (usleep + retries).
      -- An async call must return control well before that.
      assert.is_true(elapsed_ms < 20, "toggle_from_insert blocked for " .. elapsed_ms .. "ms")
    end)

    it("toggle_from_normal should return before the subprocess completes", function()
      local start = vim.loop.hrtime()
      swift_tool.toggle_from_normal()
      local elapsed_ms = (vim.loop.hrtime() - start) / 1e6

      assert.is_true(elapsed_ms < 20, "toggle_from_normal blocked for " .. elapsed_ms .. "ms")
    end)

    it("toggle_from_insert should eventually invoke its callback", function()
      local done = false
      local success = nil

      swift_tool.toggle_from_insert(function(result)
        done = true
        success = result
      end)

      vim.wait(1000, function() return done end, 10)

      assert.is_true(done, "callback should be invoked asynchronously")
      assert.is_true(success == nil or type(success) == "boolean")
    end)
  end)

  describe("4.3: InsertEnter/InsertLeave autocmds do not block the main loop", function()
    it("should return control quickly on InsertLeave", function()
      local start = vim.loop.hrtime()
      vim.cmd("doautocmd InsertLeave")
      local elapsed_ms = (vim.loop.hrtime() - start) / 1e6

      assert.is_true(elapsed_ms < 20, "InsertLeave blocked for " .. elapsed_ms .. "ms")
    end)

    it("should return control quickly on InsertEnter", function()
      local start = vim.loop.hrtime()
      vim.cmd("doautocmd InsertEnter")
      local elapsed_ms = (vim.loop.hrtime() - start) / 1e6

      assert.is_true(elapsed_ms < 20, "InsertEnter blocked for " .. elapsed_ms .. "ms")
    end)
  end)
end)
