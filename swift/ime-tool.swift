import Carbon
import Foundation

// MARK: - Debug Logging

let debugLogEnabled = ProcessInfo.processInfo.environment["IME_AUTO_DEBUG"] != nil
let debugLogPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/share/nvim/ime-auto/debug.log")

func debugLog(_ message: String) {
    if debugLogEnabled {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        if let handle = FileHandle(forWritingAtPath: debugLogPath.path) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        } else {
            // Create file if it doesn't exist
            try? logMessage.write(to: debugLogPath, atomically: true, encoding: .utf8)
        }
    }
    fputs(message + "\n", stderr)
}

// MARK: - Helper Functions

// Get current input source ID
func getCurrentInputSourceID() -> String? {
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let sourceID = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else {
        return nil
    }
    return Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
}

// Send Eisu (英数) key to force English input mode
func sendEisuKey() {
    let keyCode: CGKeyCode = 0x66  // kVK_JIS_Eisu

    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
        keyDownEvent.post(tap: .cghidEventTap)
    }
    usleep(10000) // 10ms

    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
        keyUpEvent.post(tap: .cghidEventTap)
    }
    usleep(50000) // 50ms for the input mode to settle
}

// Send Kana (かな) key to force Hiragana input mode
func sendKanaKey() {
    let keyCode: CGKeyCode = 0x68  // kVK_JIS_Kana

    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
        keyDownEvent.post(tap: .cghidEventTap)
    }
    usleep(10000) // 10ms

    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
        keyUpEvent.post(tap: .cghidEventTap)
    }
    usleep(50000) // 50ms for the input mode to settle
}

// Detect keyboard type
// Note: LMGetKbdType() returns different values on Apple Silicon Macs
// Instead, we check if Eisu/Kana keys are available by checking keyboard layout
func isJISKeyboard() -> Bool {
    let keyboardType = LMGetKbdType()

    // Known JIS keyboard types
    if keyboardType == 40 || keyboardType == 41 {
        return true
    }

    // On Apple Silicon and newer Macs, check for Japanese keyboard layout
    // by looking for Japanese-specific input sources
    if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
        for source in sources {
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                // If we have com.apple.inputmethod.Kotoeri (built-in Japanese IME),
                // it's likely a JIS keyboard setup
                if id == "com.apple.inputmethod.Kotoeri.Japanese" {
                    return true
                }
            }
        }
    }

    // Fallback: assume JIS if keyboard type is not standard US (42, 43)
    // This is not perfect but covers most cases
    if keyboardType != 42 && keyboardType != 43 {
        debugLog("[isJISKeyboard] Unknown keyboard type \(keyboardType), assuming JIS")
        return true
    }

    return false
}

// Check if an input source ID is a Japanese IME
func isJapaneseIME(_ sourceID: String) -> Bool {
    return sourceID.contains("Japanese") || sourceID.contains("Hiragana") || sourceID.contains("Katakana")
}

// Check if an input source ID is ASCII-capable (English)
func isEnglishIME(_ sourceID: String) -> Bool {
    return sourceID.contains("ABC") || sourceID.contains("US") || sourceID.contains("keylayout")
}

// Switch to input source by ID, returns true on success
// Also sends appropriate key event to force input mode (English/Japanese)
func switchToInputSource(_ targetID: String, forceInputMode: Bool = true) -> Bool {
    guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        debugLog("[switchToInputSource] Failed to get input source list")
        return false
    }

    for source in sources {
        if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            if id == targetID {
                debugLog("[switchToInputSource] Found target source \(targetID), calling TISSelectInputSource")
                TISSelectInputSource(source)

                // Wait for IME switch to complete (TISSelectInputSource is async)
                usleep(50000) // 50ms initial wait

                // Verify switch succeeded
                var switchSucceeded = false
                if let currentID = getCurrentInputSourceID(), currentID == targetID {
                    debugLog("[switchToInputSource] Switch verified on first check (50ms)")
                    switchSucceeded = true
                } else {
                    debugLog("[switchToInputSource] First check failed, retrying...")

                    // Retry up to 3 times if initial switch incomplete
                    for attempt in 0..<3 {
                        usleep(50000) // 50ms per retry
                        if let currentID = getCurrentInputSourceID(), currentID == targetID {
                            debugLog("[switchToInputSource] Switch verified on retry \(attempt + 1)")
                            switchSucceeded = true
                            break
                        }
                        debugLog("[switchToInputSource] Retry \(attempt + 1) failed, current=\(getCurrentInputSourceID() ?? "nil")")
                    }
                }

                if !switchSucceeded {
                    debugLog("[switchToInputSource] FAILED after all retries (target: \(targetID), current: \(getCurrentInputSourceID() ?? "nil"))")
                    return false
                }

                // Force input mode by sending key event (JIS keyboard only)
                if forceInputMode && isJISKeyboard() {
                    if isJapaneseIME(targetID) {
                        debugLog("[switchToInputSource] JIS keyboard detected - Sending Kana key to force Hiragana mode")
                        sendKanaKey()
                    } else if isEnglishIME(targetID) {
                        debugLog("[switchToInputSource] JIS keyboard detected - Sending Eisu key to force English mode")
                        sendEisuKey()
                    }
                } else if forceInputMode && !isJISKeyboard() {
                    debugLog("[switchToInputSource] Non-JIS keyboard detected - Skipping key event (not needed)")
                }

                return true
            }
        }
    }
    debugLog("[switchToInputSource] Target source \(targetID) not found in available sources")
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
        debugLog("Error: Invalid slot name. Only alphanumeric, underscore, and dash allowed.\n")
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
            debugLog("Error: Failed to create directory \(nvimDataDir.path): \(error)\n")
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
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    debugLog("[DEBUG] toggle-from-insert: current=\(currentID)\n")

    // Save current to slot A
    do {
        try writeToSlot(currentID, slot: "a")
        debugLog("[DEBUG] toggle-from-insert: saved to slot A=\(currentID)\n")
    } catch {
        debugLog("Error: Failed to write slot A: \(error.localizedDescription)\n")
        exit(1)
    }

    // Switch to slot B (if exists), otherwise switch to default English (ABC)
    let targetID = readFromSlot("b") ?? "com.apple.keylayout.ABC"
    debugLog("[DEBUG] toggle-from-insert: target=\(targetID)\n")

    if switchToInputSource(targetID) {
        let actualID = getCurrentInputSourceID()
        debugLog("[DEBUG] toggle-from-insert: switched to \(actualID ?? "nil")\n")
        exit(0)
    } else {
        debugLog("Error: Input source not found: \(targetID)\n")
        exit(1)
    }

} else if command == "toggle-from-normal" {
    // Toggle from Normal mode: save current to slot B, switch to slot A
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    debugLog("[DEBUG] toggle-from-normal: current=\(currentID)\n")

    // Save current to slot B
    do {
        try writeToSlot(currentID, slot: "b")
        debugLog("[DEBUG] toggle-from-normal: saved to slot B=\(currentID)\n")
    } catch {
        debugLog("Error: Failed to write slot B: \(error.localizedDescription)\n")
        exit(1)
    }

    // Switch to slot A (if exists), otherwise keep current
    guard let targetID = readFromSlot("a") else {
        debugLog("[DEBUG] toggle-from-normal: no slot A, staying on current\n")
        exit(0)  // No slot A, stay on current
    }

    debugLog("[DEBUG] toggle-from-normal: target=\(targetID)\n")

    if switchToInputSource(targetID) {
        let actualID = getCurrentInputSourceID()
        debugLog("[DEBUG] toggle-from-normal: switched to \(actualID ?? "nil")\n")
        exit(0)
    } else {
        debugLog("Error: Input source not found: \(targetID)\n")
        exit(1)
    }

} else if command == "toggle" {
    // Toggle between two saved IME states
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
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
            debugLog("Error: Failed to write slot B: \(error.localizedDescription)\n")
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
        debugLog("Error: Input source not found: \(target)\n")
        exit(1)
    }
} else if command == "save-insert" {
    // Save current input source to slot A (insert mode IME)
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    do {
        try writeToSlot(currentID, slot: "a")
        exit(0)
    } catch {
        debugLog("Error: Failed to write slot A: \(error.localizedDescription)\n")
        exit(1)
    }

} else if command == "save-normal" {
    // Save current input source to slot B (normal mode IME)
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    do {
        try writeToSlot(currentID, slot: "b")
        exit(0)
    } catch {
        debugLog("Error: Failed to write slot B: \(error.localizedDescription)\n")
        exit(1)
    }

} else {
    // Legacy: Switch to specified input source
    if switchToInputSource(command) {
        exit(0)
    } else {
        debugLog("Error: Input source not found: \(command)\n")
        exit(1)
    }
}
