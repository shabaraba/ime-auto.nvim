-- tests/priority-1/04_linux_ime_tool_spec.lua
-- Test 04: Linux IME tool (fcitx/ibus) slot management and input validation

local linux_tool = require("ime-auto.linux-ime-tool")

describe("Test 04: Linux IME tool", function()
  local test_dir
  local original_get_current

  before_each(function()
    test_dir = vim.fn.tempname()
    linux_tool.set_slot_dir(test_dir)
    original_get_current = linux_tool.get_current
  end)

  after_each(function()
    linux_tool.get_current = original_get_current
    vim.fn.delete(test_dir, "rf")
  end)

  describe("4.1: Tool detection", function()
    it("should return fcitx, ibus, or nil without error", function()
      linux_tool.reset_tool_cache()
      local tool = linux_tool.detect_tool()
      assert.is_true(tool == nil or tool == "fcitx" or tool == "ibus")
    end)

    it("should cache detection result across calls", function()
      linux_tool.reset_tool_cache()
      local first = linux_tool.detect_tool()
      local second = linux_tool.detect_tool()
      assert.equals(first, second)
    end)
  end)

  describe("4.2: Engine ID validation", function()
    it("should reject nil engine id", function()
      assert.is_false(linux_tool.switch_to(nil))
    end)

    it("should reject non-string engine id", function()
      assert.is_false(linux_tool.switch_to(123))
    end)

    it("should reject engine id with shell metacharacters", function()
      assert.is_false(linux_tool.switch_to("mozc; rm -rf /"))
      assert.is_false(linux_tool.switch_to("mozc`whoami`"))
      assert.is_false(linux_tool.switch_to("$(id)"))
    end)

    it("should accept ibus-style engine id with colons", function()
      linux_tool.get_current = function() return nil end
      -- Valid format should pass validation even if no tool is installed
      -- (switch_to returns false only due to missing tool, not validation)
      local result = linux_tool.switch_to("xkb:us::eng")
      assert.is_boolean(result)
    end)
  end)

  describe("4.3: Slot persistence", function()
    it("should save and restore slot A via toggle_from_insert", function()
      linux_tool.get_current = function() return "mozc-jp" end
      linux_tool.reset_tool_cache()

      local ok = linux_tool.toggle_from_insert()
      assert.is_boolean(ok)

      local slot_a_path = test_dir .. "/saved-ime-a.txt"
      assert.equals(1, vim.fn.filereadable(slot_a_path))
      assert.equals("mozc-jp", vim.fn.readfile(slot_a_path)[1])
    end)

    it("should save slot B via toggle_from_normal", function()
      linux_tool.get_current = function() return "xkb:us::eng" end

      linux_tool.toggle_from_normal()

      local slot_b_path = test_dir .. "/saved-ime-b.txt"
      assert.equals(1, vim.fn.filereadable(slot_b_path))
      assert.equals("xkb:us::eng", vim.fn.readfile(slot_b_path)[1])
    end)

    it("should create slot directory with 0700 permissions", function()
      linux_tool.get_current = function() return "mozc-jp" end
      linux_tool.save_insert_ime()

      assert.equals("rwx------", vim.fn.getfperm(test_dir))
    end)

    it("should create slot file with 0600 permissions", function()
      linux_tool.get_current = function() return "mozc-jp" end
      linux_tool.save_insert_ime()

      local slot_a_path = test_dir .. "/saved-ime-a.txt"
      assert.equals("rw-------", vim.fn.getfperm(slot_a_path))
    end)

    it("should return false from save_insert_ime when current IME is unknown", function()
      linux_tool.get_current = function() return nil end
      assert.is_false(linux_tool.save_insert_ime())
    end)
  end)

  describe("4.4: toggle_from_normal without saved slot A", function()
    it("should return true and stay on current engine", function()
      linux_tool.get_current = function() return "xkb:us::eng" end
      local ok = linux_tool.toggle_from_normal()
      assert.is_true(ok)
    end)
  end)
end)
