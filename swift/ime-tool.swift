import Carbon
import Foundation

// Get save file paths and ensure directory exists
func getSaveFilePath(slot: String = "current") -> URL {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let nvimDataDir = homeDir.appendingPathComponent(".local/share/nvim/ime-auto")

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: nvimDataDir.path) {
        do {
            try FileManager.default.createDirectory(at: nvimDataDir, withIntermediateDirectories: true, attributes: nil)
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
        // No matching input source found
        fputs("Error: Input source not found: \(target)\n", stderr)
        exit(1)
    }
    exit(1)

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
        // No matching input source found
        fputs("Error: Input source not found: \(target)\n", stderr)
        exit(1)
    }
    exit(1)

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
        // No matching input source found
        fputs("Error: Input source not found: \(target)\n", stderr)
        exit(1)
    }
    exit(1)
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
    // No matching input source found
    fputs("Error: Input source not found: \(targetID)\n", stderr)
    exit(1)
}
