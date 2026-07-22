-- tests/priority-1/04_cache_invalidation_spec.lua
-- Test 04: IME state cache invalidation after plugin-initiated switches (issue #23)

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 04: IME state cache invalidation", function()
  local original_control = nil
  local status_call_count = 0

  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")

    status_call_count = 0
    original_control = ime.control
    ime.control = function(action)
      if action == "status" then
        status_call_count = status_call_count + 1
      end
      return original_control(action)
    end
  end)

  after_each(function()
    vim.cmd("bdelete!")

    if original_control then
      ime.control = original_control
    end
  end)

  describe("4.1: on() invalidates cache", function()
    it("should query fresh status after on()", function()
      ime.get_status()
      local after_first = status_call_count

      ime.on()

      ime.get_status()
      assert.is_true(status_call_count > after_first, "get_status should re-query after on()")
    end)
  end)

  describe("4.2: off() invalidates cache", function()
    it("should query fresh status after off()", function()
      ime.get_status()
      local after_first = status_call_count

      ime.off()

      ime.get_status()
      assert.is_true(status_call_count > after_first, "get_status should re-query after off()")
    end)
  end)

  describe("4.3: restore_state() invalidates cache", function()
    it("should query fresh status after restore_state()", function()
      ime.get_status()
      local after_first = status_call_count

      ime.restore_state()

      ime.get_status()
      assert.is_true(status_call_count > after_first, "get_status should re-query after restore_state()")
    end)
  end)

  describe("4.4: unrelated status queries still use cache", function()
    it("should reuse cache when no switch happened", function()
      ime.get_status()
      local after_first = status_call_count

      ime.get_status()
      assert.equals(after_first, status_call_count, "should reuse cache when no switch happened")
    end)
  end)
end)
