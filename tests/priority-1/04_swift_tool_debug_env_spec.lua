-- tests/priority-1/04_swift_tool_debug_env_spec.lua
-- Test 04: Swift tool command execution does not depend on &shell (issue #28)

local ime_auto = require("ime-auto")
local swift_ime_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: swift-ime-tool debug env handling", function()
  local original_shell

  before_each(function()
    original_shell = vim.o.shell
  end)

  after_each(function()
    vim.o.shell = original_shell
  end)

  describe("4.1: debug=false runs correctly under an incompatible shell", function()
    it("should return real input sources even when 'shell' cannot run our command", function()
      ime_auto.setup({ debug = false })
      -- A shell stand-in that would mangle any string-based command
      -- (real broken shells like old fish/csh/tcsh reject the
      -- `VAR=1 cmd` syntax outright instead of echoing it back).
      vim.o.shell = "/bin/echo"

      local sources = swift_ime_tool.list()

      assert.is_true(sources ~= nil and #sources > 0, "should return real input sources, not shell echo output")
      assert.is_not_nil(sources[1]:match("^[%w%.%-_]+ %- .+"), "entries should look like 'id - name', not echoed args")
    end)
  end)

  describe("4.2: debug=true runs correctly under an incompatible shell", function()
    it("should not concatenate the debug env var into a shell string", function()
      ime_auto.setup({ debug = true })
      vim.o.shell = "/bin/echo"

      local sources = swift_ime_tool.list()

      assert.is_true(sources ~= nil and #sources > 0, "debug=true should not break command execution under any 'shell'")
      assert.is_not_nil(sources[1]:match("^[%w%.%-_]+ %- .+"), "entries should look like 'id - name', not echoed args")
      for _, line in ipairs(sources) do
        assert.is_nil(line:match("IME_AUTO_DEBUG"), "IME_AUTO_DEBUG must never leak into command output as literal text")
      end
    end)
  end)

  describe("4.3: get_current still returns a real input source id with debug enabled", function()
    it("should read the current input source without shell interference", function()
      ime_auto.setup({ debug = true })
      vim.o.shell = "/bin/echo"

      local current = swift_ime_tool.get_current()

      assert.is_not_nil(current, "should return the current input source id")
      assert.is_not_nil(current:match("^[%w%.%-_]+$"), "should be a bare input source id, not echoed shell args")
    end)
  end)
end)
