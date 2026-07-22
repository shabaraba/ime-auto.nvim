-- tests/priority-1/04_windows_ime_control_spec.lua
-- Test 04: Windows IME control (deterministic on/off, SendKeys assembly load)

local ime = require("ime-auto.ime")

describe("Test 04: Windows IME control", function()
  local windows = ime._windows

  describe("4.1: PowerShell command construction", function()
    it("should load System.Windows.Forms before referencing SendKeys", function()
      local cmd = windows.build_toggle_command()

      local add_type_pos = cmd:find("Add%-Type %-AssemblyName System%.Windows%.Forms")
      local send_keys_pos = cmd:find("SendKeys")

      assert.is_not_nil(add_type_pos, "Toggle command should load System.Windows.Forms")
      assert.is_not_nil(send_keys_pos, "Toggle command should reference SendKeys")
      assert.is_true(add_type_pos < send_keys_pos, "Add-Type must run before SendKeys is used")
    end)

    it("should build a status query command targeting ja-JP input method tips", function()
      local cmd = windows.build_status_command()

      assert.is_not_nil(cmd:find("ja%-JP"))
      assert.is_not_nil(cmd:find("InputMethodTips"))
    end)
  end)

  describe("4.2: Deterministic toggle decision", function()
    it("should not toggle when already in the desired 'on' state", function()
      assert.is_false(windows.should_toggle(true, true))
    end)

    it("should not toggle when already in the desired 'off' state", function()
      assert.is_false(windows.should_toggle(false, false))
    end)

    it("should toggle when current state differs from desired 'on' state", function()
      assert.is_true(windows.should_toggle(false, true))
    end)

    it("should toggle when current state differs from desired 'off' state", function()
      assert.is_true(windows.should_toggle(true, false))
    end)

    it("should refuse to toggle when current state is unknown", function()
      assert.is_false(windows.should_toggle(nil, true))
      assert.is_false(windows.should_toggle(nil, false))
    end)
  end)
end)
