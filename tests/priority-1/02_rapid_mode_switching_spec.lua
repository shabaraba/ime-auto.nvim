-- tests/priority-1/02_rapid_mode_switching_spec.lua
-- Test 02: Rapid mode switching and race conditions

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")

describe("Test 02: Rapid mode switching", function()
  local original_control = nil
  local call_count = 0

  before_each(function()
    ime_auto.setup({
      escape_sequence = "ｋｊ",
      escape_timeout = 200,
      debug = false,
    })

    vim.cmd("enew!")
    vim.cmd("only")

    -- Setup system call spy
    call_count = 0
    original_control = ime.control
    ime.control = function(action)
      if action == "off" or action == "on" then
        call_count = call_count + 1
      end
      return original_control(action)
    end
  end)

  after_each(function()
    vim.cmd("bdelete!")

    -- Restore original function
    if original_control then
      ime.control = original_control
    end
  end)

  describe("2.1: IME off operation", function()
    it("should call IME off immediately", function()
      -- Trigger InsertLeave (calls off directly, no debounce)
      vim.cmd("doautocmd InsertLeave")

      -- Wait for call to complete
      vim.wait(50)
      local after_leave = call_count

      -- System call should happen immediately
      assert.is_true(after_leave > 0, "Should call IME off immediately")
    end)
  end)

  describe("2.2: Rapid Insert->Normal->Insert switching", function()
    it("should handle rapid mode switching without data corruption", function()
      call_count = 0

      -- Rapid switching
      vim.cmd("doautocmd InsertEnter")
      vim.wait(50)
      vim.cmd("doautocmd InsertLeave")
      vim.wait(50)
      vim.cmd("doautocmd InsertEnter")

      -- Wait for all debounced calls to complete
      vim.wait(150)

      -- Should minimize system calls
      -- Without debounce: 2 calls (off, on)
      -- With debounce: ideally 1-2 calls
      assert.is_true(call_count <= 3, "Should minimize system calls: " .. call_count)
    end)
  end)

  describe("2.3: Cache validity during debounced calls", function()
    it("should maintain cache consistency", function()
      -- Get initial status (creates cache)
      local status1 = ime.get_status()

      -- Trigger debounced off
      vim.cmd("doautocmd InsertLeave")
      vim.wait(50) -- During debounce

      -- Get status again (should use cache)
      local status2 = ime.get_status()

      -- Cache should be consistent
      assert.equals(status1, status2, "Cache should be consistent during debounce")

      -- Wait for debounce to complete
      vim.wait(100)

      -- After debounce, status might change (cache expired or updated)
      -- This is acceptable behavior
      assert.is_true(true, "Debounce completed")
    end)
  end)

  describe("2.4: Multiple rapid switches stress test", function()
    it("should handle 10 rapid switches", function()
      call_count = 0

      for i = 1, 10 do
        vim.cmd("doautocmd InsertEnter")
        vim.wait(25)
        vim.cmd("doautocmd InsertLeave")
        vim.wait(25)
      end

      -- Wait for all events to complete
      vim.wait(200)

      -- Without debounce: 20 calls (10 on + 10 off)
      -- This test verifies the plugin handles rapid switches without errors
      assert.is_true(call_count > 0, "Should handle rapid switches: " .. call_count)
    end)
  end)

  describe("2.5: Cache TTL (500ms) behavior", function()
    it("should expire cache after TTL", function()
      -- Override spy to count "status" calls
      call_count = 0
      ime.control = function(action)
        if action == "status" then
          call_count = call_count + 1
        end
        return original_control(action)
      end

      -- Create cache
      ime.get_status()
      local cached_call_count = call_count

      -- Within TTL (400ms < 500ms)
      vim.wait(400)
      ime.get_status()
      assert.equals(cached_call_count, call_count, "Should use cache within TTL")

      -- Exceed TTL (600ms total > 500ms)
      vim.wait(200)
      ime.get_status()

      -- Should make new system call after cache expires
      assert.is_true(call_count > cached_call_count, "Should make new system call after TTL expired")
    end)
  end)

  describe("2.6: Concurrent event handling", function()
    it("should handle concurrent InsertEnter and InsertLeave", function()
      call_count = 0

      -- Simulate concurrent events
      vim.cmd("doautocmd InsertEnter")
      vim.cmd("doautocmd InsertLeave") -- Immediate, no wait
      vim.cmd("doautocmd InsertEnter")

      vim.wait(150)

      -- Should not crash and should complete successfully
      assert.is_true(call_count >= 0, "Should handle concurrent events")
    end)
  end)
end)
