-- tests/priority-1/04_instance_isolation_spec.lua
-- Test 04: Slot file isolation between concurrent Neovim instances (issue #31)

local swift_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: Slot file instance isolation", function()
  local original_system
  local last_argv

  before_each(function()
    original_system = vim.system
    last_argv = nil

    vim.system = function(argv, _, callback)
      last_argv = argv
      local completed = { stdout = "", code = 0 }
      if callback then
        callback(completed)
        return { wait = function() return completed end }
      end
      return {
        wait = function() return completed end,
      }
    end
  end)

  after_each(function()
    vim.system = original_system
  end)

  describe("4.1: Slot-touching commands receive an instance identifier", function()
    local commands = {
      { name = "toggle_from_insert", fn = function() swift_tool.toggle_from_insert() end },
      { name = "toggle_from_normal", fn = function() swift_tool.toggle_from_normal() end },
    }

    for _, case in ipairs(commands) do
      it("passes an extra instance-id argument for " .. case.name, function()
        case.fn()

        assert.is_not_nil(last_argv, "vim.system() should have been called")

        local expected_id = swift_tool.sanitize_instance_id(
          vim.v.servername ~= "" and vim.v.servername or tostring(vim.fn.getpid())
        )
        assert.equals(expected_id, last_argv[#last_argv],
          "last positional argument should be the sanitized instance id")
      end)
    end
  end)

  describe("4.2: Sanitization keeps distinct instances distinct", function()
    it("produces different ids for different raw identifiers", function()
      local id_a = swift_tool.sanitize_instance_id("/tmp/nvim.instanceA.0")
      local id_b = swift_tool.sanitize_instance_id("/tmp/nvim.instanceB.0")

      assert.are_not.equal(id_a, id_b, "distinct instances must map to distinct ids")
    end)

    it("produces a stable id for the same raw identifier", function()
      local first = swift_tool.sanitize_instance_id("/tmp/nvim.same.0")
      local second = swift_tool.sanitize_instance_id("/tmp/nvim.same.0")

      assert.equals(first, second)
    end)

    it("strips path-unsafe characters (e.g. slashes) from socket paths", function()
      local id = swift_tool.sanitize_instance_id("/tmp/nvim.42.0")

      assert.is_nil(id:find("/", 1, true), "sanitized id must not contain '/'")
      assert.matches("^[%w%.%-_]+$", id)
    end)
  end)

  describe("4.3: Falls back to PID when the raw identifier is empty", function()
    it("returns the process id for an empty string", function()
      local id = swift_tool.sanitize_instance_id("")

      assert.equals(tostring(vim.fn.getpid()), id)
    end)

    it("returns the process id for nil", function()
      local id = swift_tool.sanitize_instance_id(nil)

      assert.equals(tostring(vim.fn.getpid()), id)
    end)
  end)

  describe("4.4: Non-slot commands do not require an instance id", function()
    it("does not error when calling list/get_current", function()
      assert.has_no.errors(function()
        swift_tool.list()
      end)
      assert.has_no.errors(function()
        swift_tool.get_current()
      end)
    end)

    it("does not append an instance id argument to 'list'", function()
      swift_tool.list()

      -- Only the binary path and the "list" argument should be present
      assert.equals(2, #last_argv)
      assert.equals("list", last_argv[2])
    end)
  end)
end)
