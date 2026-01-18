import Carbon
import Foundation

// MARK: - Helper Functions

// Get current input source ID
func getCurrentInputSourceID() -> String? {
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else {
        return nil
    }
    return Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
}

// Switch to input source by ID, returns true on success
func switchToInputSource(_ targetID: String) -> Bool {
    guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        return false
    }

    for source in sources {
        if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            if id == targetID {
                TISSelectInputSource(source)
                return true
            }
        }
    }
    return false
}

// Write IME ID to slot with secure permissions
func writeToSlot(_ id: String, slot: String) throws {
    let slotFile = getSaveFilePath(slot: slot)
    try id.write(to: slotFile, atomically: true, encoding: .utf8)
    // Set secure file permissions (owner read/write only)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: slotFile.path)
}

// Read IME ID from slot
func readFromSlot(_ slot: String) -> String? {
    let slotFile = getSaveFilePath(slot: slot)
    return try? String(contentsOf: slotFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - File Path Management

// Get save file paths and ensure directory exists
func getSaveFilePath(slot: String = "current") -> URL {
    // Validate slot parameter to prevent path traversal
    let validSlotPattern = "^[a-zA-Z0-9_-]+$"
    guard let regex = try? NSRegularExpression(pattern: validSlotPattern),
          regex.firstMatch(in: slot, range: NSRange(slot.startIndex..., in: slot)) != nil else {
        fputs("Error: Invalid slot name. Only alphanumeric, underscore, and dash allowed.\n", stderr)
        exit(1)
    }

    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let nvimDataDir = homeDir.appendingPathComponent(".local/share/nvim/ime-auto")

    // Create directory if it doesn't exist with secure permissions
    if !FileManager.default.fileExists(atPath: nvimDataDir.path) {
        do {
            let attributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o700  // Owner read/write/execute only
            ]
            try FileManager.default.createDirectory(at: nvimDataDir, withIntermediateDirectories: true, attributes: attributes)
        } catch {
            fputs("Error: Failed to create directory \(nvimDataDir.path): \(error)\n", stderr)
            exit(1)
        }
    }

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
                if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                    let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
                    print("\(id) - \(name)")
                } else {
                    print(id)
                }
            }
        }
    }
} else if command == "toggle-from-insert" {
    // Toggle from Insert mode: save current to slot A, switch to slot B
    guard let currentID = getCurrentInputSourceID() else {
        fputs("Error: Failed to get current input source\n", stderr)
        exit(1)
    }

    // Save current to slot A
    do {
        try writeToSlot(currentID, slot: "a")
    } catch {
        fputs("Error: Failed to write slot A: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    // Switch to slot B (if exists), otherwise switch to default English (ABC)
    let targetID = readFromSlot("b") ?? "com.apple.keylayout.ABC"

    if switchToInputSource(targetID) {
        exit(0)
    } else {
        fputs("Error: Input source not found: \(targetID)\n", stderr)
        exit(1)
    }

} else if command == "toggle-from-normal" {
    // Toggle from Normal mode: save current to slot B, switch to slot A
    guard let currentID = getCurrentInputSourceID() else {
        fputs("Error: Failed to get current input source\n", stderr)
        exit(1)
    }

    // Save current to slot B
    do {
        try writeToSlot(currentID, slot: "b")
    } catch {
        fputs("Error: Failed to write slot B: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    // Switch to slot A (if exists), otherwise keep current
    guard let targetID = readFromSlot("a") else {
        exit(0)  // No slot A, stay on current
    }

    if switchToInputSource(targetID) {
        exit(0)
    } else {
        fputs("Error: Input source not found: \(targetID)\n", stderr)
        exit(1)
    }

} else if command == "toggle" {
    // Toggle between two saved IME states
    guard let currentID = getCurrentInputSourceID() else {
        fputs("Error: Failed to get current input source\n", stderr)
        exit(1)
    }

    // Load slot A and B
    let slotAID = readFromSlot("a")
    let slotBID = readFromSlot("b")

    // Determine which slot to switch to
    let targetID: String?
    if let a = slotAID, currentID == a {
        // Currently on A, switch to B (if exists)
        targetID = slotBID
    } else if let b = slotBID, currentID == b {
        // Currently on B, switch to A (if exists)
        targetID = slotAID
    } else {
        // Current is neither A nor B - save current to slot B, switch to slot A
        do {
            try writeToSlot(currentID, slot: "b")
        } catch {
            fputs("Error: Failed to write slot B: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        targetID = slotAID
    }

    // Switch to target (or stay on current if no target)
    guard let target = targetID else {
        exit(0)
    }

    if switchToInputSource(target) {
        exit(0)
    } else {
        fputs("Error: Input source not found: \(target)\n", stderr)
        exit(1)
    }
} else if command == "save-insert" {
    // Save current input source to slot A (insert mode IME)
    guard let currentID = getCurrentInputSourceID() else {
        fputs("Error: Failed to get current input source\n", stderr)
        exit(1)
    }

    do {
        try writeToSlot(currentID, slot: "a")
        exit(0)
    } catch {
        fputs("Error: Failed to write slot A: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

} else if command == "save-normal" {
    // Save current input source to slot B (normal mode IME)
    guard let currentID = getCurrentInputSourceID() else {
        fputs("Error: Failed to get current input source\n", stderr)
        exit(1)
    }

    do {
        try writeToSlot(currentID, slot: "b")
        exit(0)
    } catch {
        fputs("Error: Failed to write slot B: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

} else {
    // Legacy: Switch to specified input source
    if switchToInputSource(command) {
        exit(0)
    } else {
        fputs("Error: Input source not found: \(command)\n", stderr)
        exit(1)
    }
}
