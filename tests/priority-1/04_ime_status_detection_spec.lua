-- tests/priority-1/04_ime_status_detection_spec.lua
-- Test 04: IME status detection is TIS-property-based, not ID string matching

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local config = require("ime-auto.config")

describe("Test 04: IME status detection (TIS-based)", function()
  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })
  end)

  if config.detect_os() ~= "macos" then
    return
  end

  describe("4.1: macOS status trusts the Swift tool result as-is", function()
    local swift_tool
    local original_get_status

    before_each(function()
      swift_tool = require("ime-auto.swift-ime-tool")
      original_get_status = swift_tool.get_status
    end)

    after_each(function()
      swift_tool.get_status = original_get_status
    end)

    it("returns true when Swift reports the source is composing (non-ASCII)", function()
      swift_tool.get_status = function() return true end
      assert.is_true(ime.control("status"))
    end)

    it("returns false for an ASCII-capable source, even if its ID is not com.apple.keylayout.*", function()
      -- Regression for issue #19: sources such as Kotoeri's Roman (英数) mode
      -- or a Korean IME's ASCII mode used to be misclassified as "on" purely
      -- because their ID didn't match com.apple.keylayout.*.
      swift_tool.get_status = function() return false end
      assert.is_false(ime.control("status"))
    end)

    it("does not fall back to true when the Swift tool cannot determine status", function()
      swift_tool.get_status = function() return nil end
      assert.is_nil(ime.control("status"))
    end)
  end)

  describe("4.2: swift-ime-tool.get_status output parsing", function()
    local swift_tool
    local original_system

    before_each(function()
      swift_tool = require("ime-auto.swift-ime-tool")
      swift_tool.ensure_compiled()
      original_system = vim.system
    end)

    after_each(function()
      vim.system = original_system
    end)

    local function stub_system(stdout, code)
      vim.system = function(_, _)
        return {
          wait = function()
            return { stdout = stdout, code = code }
          end,
        }
      end
    end

    it("returns true for 'on' output", function()
      stub_system("on\n", 0)
      assert.is_true(swift_tool.get_status())
    end)

    it("returns false for 'off' output", function()
      stub_system("off\n", 0)
      assert.is_false(swift_tool.get_status())
    end)

    it("returns nil for unrecognized output", function()
      stub_system("garbage\n", 0)
      assert.is_nil(swift_tool.get_status())
    end)

    it("returns nil when the underlying command fails", function()
      stub_system("", 1)
      assert.is_nil(swift_tool.get_status())
    end)
  end)
end)
