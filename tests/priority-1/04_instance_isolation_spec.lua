-- tests/priority-1/04_instance_isolation_spec.lua
-- Test 04: Slot file isolation between concurrent Neovim instances (issue #31)

local swift_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: Slot file instance isolation", function()
  local original_system
  local last_cmd

  before_each(function()
    original_system = vim.fn.system
    last_cmd = nil

    vim.fn.system = function(cmd)
      last_cmd = cmd
      -- Run a real no-op command so Neovim sets v:shell_error itself
      -- (v:shell_error is read-only and cannot be assigned from Lua)
      return original_system("true")
    end
  end)

  after_each(function()
    vim.fn.system = original_system
  end)

  describe("4.1: Slot-touching commands receive an instance identifier", function()
    local commands = {
      { name = "toggle", fn = function() swift_tool.toggle() end },
      { name = "save_insert_ime", fn = function() swift_tool.save_insert_ime() end },
      { name = "save_normal_ime", fn = function() swift_tool.save_normal_ime() end },
      { name = "toggle_from_insert", fn = function() swift_tool.toggle_from_insert() end },
      { name = "toggle_from_normal", fn = function() swift_tool.toggle_from_normal() end },
    }

    for _, case in ipairs(commands) do
      it("passes an extra instance-id argument for " .. case.name, function()
        case.fn()

        assert.is_not_nil(last_cmd, "system() should have been called")

        local expected_id = swift_tool.sanitize_instance_id(
          vim.v.servername ~= "" and vim.v.servername or tostring(vim.fn.getpid())
        )
        assert.is_true(last_cmd:find(vim.fn.shellescape(expected_id), 1, true) ~= nil,
          "command should include sanitized instance id: " .. last_cmd)
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
    it("does not error when calling list/get_current/switch_to", function()
      assert.has_no.errors(function()
        swift_tool.list()
      end)
      assert.has_no.errors(function()
        swift_tool.get_current()
      end)
      assert.has_no.errors(function()
        swift_tool.switch_to("com.apple.keylayout.ABC")
      end)
    end)

    it("does not append an instance id argument to 'list'", function()
      swift_tool.list()

      -- Only the binary path and the "list" argument should be present
      local escaped_list = vim.fn.shellescape("list")
      assert.is_true(last_cmd:find(escaped_list, 1, true) ~= nil)
      -- No trailing extra shell-escaped token after "list"
      local after_list = last_cmd:sub(last_cmd:find(escaped_list, 1, true) + #escaped_list)
      assert.equals("", vim.trim(after_list))
    end)
  end)
end)
