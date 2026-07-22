-- tests/priority-1/04_custom_status_spec.lua
-- Test 04: ime_method='custom' status handling (issue #24)

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 04: Custom IME method status handling", function()
  after_each(function()
    ime_auto.setup({ ime_method = "builtin" })
  end)

  describe("4.1: custom_status_true_pattern converts output to boolean", function()
    it("should return true when output matches the pattern", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "echo ja" },
        custom_status_true_pattern = "^ja$",
      })

      assert.equals(true, ime.control("status"))
    end)

    it("should return false when output does not match the pattern", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "echo en" },
        custom_status_true_pattern = "^ja$",
      })

      assert.equals(false, ime.control("status"))
    end)
  end)

  describe("4.2: missing custom_status_true_pattern", function()
    it("should return nil instead of a raw string", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "echo ja" },
      })

      assert.is_nil(ime.control("status"))
    end)
  end)

  describe("4.3: failing custom status command", function()
    it("should return nil when the command exits non-zero", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "exit 1" },
        custom_status_true_pattern = "^ja$",
      })

      assert.is_nil(ime.control("status"))
    end)
  end)

  describe("4.4: invalid custom_status_true_pattern", function()
    it("should return nil instead of raising an error", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "echo ja" },
        custom_status_true_pattern = "(",
      })

      assert.is_nil(ime.control("status"))
    end)
  end)

  describe("4.5: get_status falls back to last saved state", function()
    it("should not report the raw command string as truthy status", function()
      ime_auto.setup({
        ime_method = "custom",
        custom_commands = { status = "echo ja" },
      })

      local status = ime.get_status()
      assert.is_true(status == nil or type(status) == "boolean", "Should never leak a raw string")
    end)
  end)
end)
