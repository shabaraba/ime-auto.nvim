local M = {}

local swift_bin_path = nil

-- Swift source code for IME control
local swift_source = [[
import Carbon
import Foundation

// Get save file paths
func getSaveFilePath(slot: String = "current") -> URL {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let nvimDataDir = homeDir.appendingPathComponent(".local/share/nvim/ime-auto")
    return nvimDataDir.appendingPathComponent("saved-ime-\(slot).txt")
}

guard CommandLine.arguments.count > 1 else {
    // No argument: get current input source
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        print(id)
    }
    exit(0)
}

let command = CommandLine.arguments[1]

if command == "list" {
    // List all selectable input sources
    if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
        for source in sources {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

                var isSelectable = false
                if let selectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) {
                    let selectable = Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
                    isSelectable = CFBooleanGetValue(selectable)
                }

                if isSelectable {
                    print(id)
                }
            }
        }
    }
} else if command == "toggle-from-insert" {
    // Toggle from Insert mode: save current to slot A, switch to slot B
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    var currentID: String? = nil
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        currentID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
    }

    // Save current to slot A
    if let id = currentID {
        let slotA = getSaveFilePath(slot: "a")
        try? id.write(to: slotA, atomically: true, encoding: .utf8)
    }

    // Switch to slot B (if exists), otherwise switch to default English (ABC)
    let slotB = getSaveFilePath(slot: "b")
    var targetID: String? = try? String(contentsOf: slotB, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

    // If slot B doesn't exist, use default English input source
    if targetID == nil {
        targetID = "com.apple.keylayout.ABC"
    }

    if let target = targetID {
        if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
            for source in sources {
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                    if id == target {
                        TISSelectInputSource(source)
                        exit(0)
                    }
                }
            }
        }
    }
    exit(0)

} else if command == "toggle-from-normal" {
    // Toggle from Normal mode: save current to slot B, switch to slot A
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    var currentID: String? = nil
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        currentID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
    }

    // Save current to slot B
    if let id = currentID {
        let slotB = getSaveFilePath(slot: "b")
        try? id.write(to: slotB, atomically: true, encoding: .utf8)
    }

    // Switch to slot A (if exists), otherwise keep current
    let slotA = getSaveFilePath(slot: "a")
    var targetID: String? = try? String(contentsOf: slotA, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

    // If slot A doesn't exist, just stay on current (don't switch)
    if targetID == nil {
        exit(0)
    }

    if let target = targetID {
        if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
            for source in sources {
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                    if id == target {
                        TISSelectInputSource(source)
                        exit(0)
                    }
                }
            }
        }
    }
    exit(0)

} else if command == "toggle" {
    // Toggle between two saved IME states
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    var currentID: String? = nil
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        currentID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
    }

    // Load slot A and B
    let slotA = getSaveFilePath(slot: "a")
    let slotB = getSaveFilePath(slot: "b")
    let slotAID = try? String(contentsOf: slotA, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let slotBID = try? String(contentsOf: slotB, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

    // Determine which slot to switch to
    var targetID: String? = nil
    if let current = currentID, let a = slotAID, current == a {
        // Currently on A, switch to B (if exists)
        if let b = slotBID {
            targetID = b
        } else {
            // No slot B exists, stay on current
            exit(0)
        }
    } else if let current = currentID, let b = slotBID, current == b {
        // Currently on B, switch to A (if exists)
        if let a = slotAID {
            targetID = a
        } else {
            // No slot A exists, stay on current
            exit(0)
        }
    } else if let current = currentID {
        // Current is neither A nor B
        // Save current to slot B, switch to slot A (if exists)
        try? current.write(to: slotB, atomically: true, encoding: .utf8)
        if let a = slotAID {
            targetID = a
        } else {
            // No slot A exists, just stay on current
            exit(0)
        }
    }

    // Switch to target
    if let target = targetID {
        if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
            for source in sources {
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                    if id == target {
                        TISSelectInputSource(source)
                        exit(0)
                    }
                }
            }
        }
    }
} else if command == "save-insert" {
    // Save current input source to slot A (insert mode IME)
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        let saveFile = getSaveFilePath(slot: "a")
        try? id.write(to: saveFile, atomically: true, encoding: .utf8)
    }
} else if command == "save-normal" {
    // Save current input source to slot B (normal mode IME)
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    if let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        let saveFile = getSaveFilePath(slot: "b")
        try? id.write(to: saveFile, atomically: true, encoding: .utf8)
    }
} else {
    // Legacy: Switch to specified input source
    let targetID = command
    if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
        for source in sources {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                if id == targetID {
                    TISSelectInputSource(source)
                    exit(0)
                }
            }
        }
    }
}
]]

-- Compile Swift tool if not already compiled
function M.ensure_compiled()
  if swift_bin_path and vim.fn.filereadable(swift_bin_path) == 1 then
    return true
  end

  local data_dir = vim.fn.stdpath('data')
  local ime_dir = data_dir .. '/ime-auto'
  local source_path = ime_dir .. '/swift-ime.swift'
  swift_bin_path = ime_dir .. '/swift-ime'

  -- Create directory if it doesn't exist
  vim.fn.mkdir(ime_dir, 'p')

  -- Check if binary already exists and is recent
  if vim.fn.filereadable(swift_bin_path) == 1 then
    return true
  end

  -- Write Swift source code
  local file = io.open(source_path, 'w')
  if not file then
    return false, "Failed to write Swift source file"
  end
  file:write(swift_source)
  file:close()

  -- Compile Swift code
  local compile_cmd = string.format('swiftc "%s" -o "%s" 2>&1', source_path, swift_bin_path)
  local result = vim.fn.system(compile_cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Failed to compile Swift tool: " .. result
  end

  return true
end

-- Get current input source
function M.get_current()
  local ok = M.ensure_compiled()
  if not ok then
    return nil
  end

  local result = vim.fn.system(swift_bin_path)
  if vim.v.shell_error == 0 and result then
    return result:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return nil
end

-- Switch to specified input source
function M.switch_to(source_id)
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" "%s"', swift_bin_path, source_id))
  return vim.v.shell_error == 0
end

-- List all available input sources
function M.list()
  local ok = M.ensure_compiled()
  if not ok then
    return nil
  end

  local result = vim.fn.system(string.format('"%s" list', swift_bin_path))
  if vim.v.shell_error == 0 and result then
    local sources = {}
    for line in result:gmatch("[^\r\n]+") do
      if line and line ~= "" then
        table.insert(sources, line)
      end
    end
    return sources
  end
  return nil
end

-- Toggle between insert mode and normal mode IME
function M.toggle()
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" toggle', swift_bin_path))
  return vim.v.shell_error == 0
end

-- Save current IME as insert mode IME (slot A)
function M.save_insert_ime()
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" save-insert', swift_bin_path))
  return vim.v.shell_error == 0
end

-- Save current IME as normal mode IME (slot B)
function M.save_normal_ime()
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" save-normal', swift_bin_path))
  return vim.v.shell_error == 0
end

-- Toggle from Insert mode: save current to slot A, switch to slot B
function M.toggle_from_insert()
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" toggle-from-insert', swift_bin_path))
  return vim.v.shell_error == 0
end

-- Toggle from Normal mode: save current to slot B, switch to slot A
function M.toggle_from_normal()
  local ok = M.ensure_compiled()
  if not ok then
    return false
  end

  vim.fn.system(string.format('"%s" toggle-from-normal', swift_bin_path))
  return vim.v.shell_error == 0
end

return M
