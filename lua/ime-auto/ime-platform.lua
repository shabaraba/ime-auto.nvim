--- OS-specific IME control command execution
--- @module ime-auto.ime-platform

local M = {}

function M.macos(action)
  local swift_tool = require("ime-auto.swift-ime-tool")

  if action == "off" then
    swift_tool.toggle_from_insert()
  elseif action == "on" then
    swift_tool.toggle_from_normal()
  elseif action == "status" then
    -- Trust the Swift tool's TIS-property-based (ASCII capable) judgment
    -- instead of re-deriving it from the input source ID string.
    return swift_tool.get_status()
  end
end

function M.windows(action)
  local windows_tool = require("ime-auto.windows-ime-tool")

  if action == "off" then
    return windows_tool.toggle_from_insert()
  elseif action == "on" then
    return windows_tool.toggle_from_normal()
  elseif action == "status" then
    local result = windows_tool.get_current()
    if not result then return false end

    -- Japanese language tag is 0411; any registered IME under it counts as active
    return result:match("^0411:") ~= nil
  end
end

function M.linux(action)
  local linux_tool = require("ime-auto.linux-ime-tool")

  if action == "off" then
    return linux_tool.toggle_from_insert()
  elseif action == "on" then
    return linux_tool.toggle_from_normal()
  elseif action == "status" then
    return linux_tool.is_active()
  end
end

return M
