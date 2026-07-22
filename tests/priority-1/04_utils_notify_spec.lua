-- tests/priority-1/04_utils_notify_spec.lua
-- Test 04: utils.notify default level handling

local ime_auto = require("ime-auto")
local utils = require("ime-auto.utils")

describe("Test 04: utils.notify default level handling", function()
  before_each(function()
    ime_auto.setup({
      debug = false,
    })
  end)

  describe("4.1: level omitted", function()
    it("should not error when level is omitted and debug is false", function()
      assert.has_no.errors(function()
        utils.notify("test message")
      end)
    end)
  end)

  describe("4.2: explicit levels still respected", function()
    it("should not error with an explicit WARN level", function()
      assert.has_no.errors(function()
        utils.notify("test warning", vim.log.levels.WARN)
      end)
    end)

    it("should not error with an explicit INFO level", function()
      assert.has_no.errors(function()
        utils.notify("test info", vim.log.levels.INFO)
      end)
    end)
  end)
end)
