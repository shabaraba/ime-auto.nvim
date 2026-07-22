-- tests/priority-1/04_escape_race_condition_spec.lua
-- Test 04: Escape sequence race condition handling (issue #25)

local ime_auto = require("ime-auto")
local ime = require("ime-auto.ime")
local escape = require("ime-auto.escape")

describe("Test 04: Escape sequence race condition handling", function()
  local original_save_state = nil
  local original_notify = nil
  local save_state_calls = 0
  local notify_calls = {}

  -- Simulates a real InsertCharPre + insertion cycle: fires the plugin's
  -- callback with vim.v.char set, then (like Neovim itself would) inserts
  -- the character at the cursor unless the callback cleared v:char.
  local function simulate_char(char)
    vim.v.char = char
    escape.on_insert_char_pre()

    if vim.v.char ~= "" then
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local new_line = vim.fn.strpart(line, 0, col) .. vim.v.char .. vim.fn.strpart(line, col)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { 1, col + vim.fn.strlen(vim.v.char) })
    end
  end

  before_each(function()
    ime_auto.setup({
      escape_sequence = "kj",
      escape_timeout = 200,
      debug = false,
      ime_method = "custom",
      custom_commands = { status = "echo 0" },
    })

    vim.cmd("enew!")
    vim.cmd("only")
    -- Allows the cursor to sit right after the last character, matching
    -- real Insert mode behavior (headless Normal mode otherwise clamps it).
    vim.opt.virtualedit = "onemore"

    save_state_calls = 0
    original_save_state = ime.save_state
    ime.save_state = function()
      save_state_calls = save_state_calls + 1
      return original_save_state()
    end

    notify_calls = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = msg, level = level })
    end
  end)

  after_each(function()
    ime.save_state = original_save_state
    vim.notify = original_notify
    vim.opt.virtualedit = ""
    pcall(vim.cmd, "bdelete!")
  end)

  local function notified_matching(pattern)
    for _, call in ipairs(notify_calls) do
      if call.msg:match(pattern) then
        return true
      end
    end
    return false
  end

  describe("4.1: Clean escape sequence (no race)", function()
    it("should remove the escape sequence and finalize immediately", function()
      simulate_char("k")
      simulate_char("j")
      vim.wait(100)

      assert.equals("", vim.api.nvim_get_current_line())
      assert.equals(1, save_state_calls, "IME state should be saved once")
    end)

    it("should not insert the second escape character into the buffer", function()
      simulate_char("k")
      assert.equals("k", vim.api.nvim_get_current_line())

      simulate_char("j")
      -- Second character must be cancelled synchronously (v:char == ""),
      -- before the deferred cleanup even runs.
      assert.equals("k", vim.api.nvim_get_current_line())

      vim.wait(100)
      assert.equals("", vim.api.nvim_get_current_line())
    end)
  end)

  describe("4.2: Race condition - burst input before scheduled cleanup", function()
    it("should abort safely, notify, and leave the buffer uncorrupted", function()
      -- Simulate an IME multi-character commit or macro replay: several
      -- more characters land in the buffer before vim.schedule() gets a
      -- chance to run the deferred escape-sequence cleanup.
      simulate_char("k")
      simulate_char("j")
      simulate_char("e")
      simulate_char("x")
      simulate_char("t")
      simulate_char("r")
      simulate_char("a")

      vim.wait(100)

      -- Escape sequence must NOT have been silently applied at the wrong
      -- position; original first character and burst text stay intact.
      assert.equals("kextra", vim.api.nvim_get_current_line())
      assert.equals(0, save_state_calls, "IME state must not be saved on aborted escape")
      assert.is_true(
        notified_matching("Escape sequence aborted"),
        "Should notify about the aborted escape sequence instead of failing silently"
      )
    end)

    it("should notify even when debug mode is disabled", function()
      ime_auto.setup({
        escape_sequence = "kj",
        escape_timeout = 200,
        debug = false,
        ime_method = "custom",
        custom_commands = { status = "echo 0" },
      })

      simulate_char("k")
      simulate_char("j")
      simulate_char("z")

      vim.wait(100)

      assert.is_true(
        notified_matching("aborted"),
        "Race abort notifications must not be gated behind debug mode"
      )
    end)
  end)

  describe("4.3: No false trigger on partial input", function()
    it("should not finalize or notify when only the first character is typed", function()
      simulate_char("k")
      vim.wait(300)

      assert.equals("k", vim.api.nvim_get_current_line())
      assert.equals(0, save_state_calls)
      assert.is_false(notified_matching("Escape sequence"))
    end)
  end)
end)
