-- tests/priority-1/04_async_command_serialization_spec.lua
-- Test 04: Async Swift commands run one at a time in call order

local swift_ime_tool = require("ime-auto.swift-ime-tool")

describe("Test 04: swift-ime-tool async command serialization", function()
  local original_system
  local started
  local pending_exits

  before_each(function()
    original_system = vim.system
    started = {}
    pending_exits = {}
    vim.system = function(argv, _, on_exit)
      table.insert(started, argv[2])
      table.insert(pending_exits, function()
        on_exit({ stdout = "", code = 0 })
      end)
    end
  end)

  after_each(function()
    vim.system = original_system
  end)

  local function finish_next()
    table.remove(pending_exits, 1)()
    vim.wait(50, function() return false end)
  end

  it("should not start the next command until the previous one exits", function()
    swift_ime_tool.toggle_from_insert()
    swift_ime_tool.toggle_from_normal()

    assert.are.equal(1, #started)
    assert.are.equal("toggle-from-insert", started[1])

    finish_next()

    assert.are.equal(2, #started)
    assert.are.equal("toggle-from-normal", started[2])

    finish_next()
  end)

  it("should keep draining the queue when a callback raises", function()
    swift_ime_tool.toggle_from_insert(function() error("boom") end)
    swift_ime_tool.toggle_from_normal()

    finish_next()

    assert.are.equal(2, #started)

    finish_next()
  end)
end)
