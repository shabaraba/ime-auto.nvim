import Carbon
import Foundation

// MARK: - Debug Logging

let debugLogEnabled = ProcessInfo.processInfo.environment["IME_AUTO_DEBUG"] != nil
let nvimDataDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/share/nvim/ime-auto")
let debugLogPath = nvimDataDir.appendingPathComponent("debug.log")

// Ensure the data directory exists with secure permissions (owner rwx only)
func ensureDataDirExists() {
    guard !FileManager.default.fileExists(atPath: nvimDataDir.path) else { return }
    try? FileManager.default.createDirectory(
        at: nvimDataDir, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
}

func debugLog(_ message: String) {
    if debugLogEnabled {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        ensureDataDirExists()
        if !FileManager.default.fileExists(atPath: debugLogPath.path) {
            FileManager.default.createFile(atPath: debugLogPath.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        if let handle = FileHandle(forWritingAtPath: debugLogPath.path) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        }

        fputs(message + "\n", stderr)
    }
}

// MARK: - Helper Functions

// Read a string-valued TIS property (e.g. kTISPropertyInputSourceID) from an input source
func inputSourceProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let ptr = TISGetInputSourceProperty(source, key) else {
        return nil
    }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}

// Check if a boolean CFTypeRef property of an input source is true
func boolInputSourceProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let ptr = TISGetInputSourceProperty(source, key) else {
        return false
    }
    return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
}

// Get current input source ID
func getCurrentInputSourceID() -> String? {
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    return inputSourceProperty(current, kTISPropertyInputSourceID)
}

// Check whether this process has Accessibility permission granted.
// Posting CGEvents (Eisu/Kana key events) is silently dropped by the OS
// without this permission, so callers must check before posting.
func checkAccessibilityPermission() -> Bool {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        debugLog("Warning: Accessibility permission not granted. Key events will not be sent. Grant permission in System Settings > Privacy & Security > Accessibility.")
    }
    return trusted
}

let kVKJISEisu: CGKeyCode = 0x66
let kVKJISKana: CGKeyCode = 0x68

// Send a key event (key down + up) to force an input mode switch
func sendKey(_ code: CGKeyCode) {
    guard checkAccessibilityPermission() else { return }

    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true) {
        keyDownEvent.post(tap: .cghidEventTap)
    }
    usleep(10000) // 10ms

    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) {
        keyUpEvent.post(tap: .cghidEventTap)
    }
    usleep(50000) // 50ms for the input mode to settle
}

// Check if an input source ID matches a known Kotoeri Japanese variant
// (old and current macOS naming conventions)
func isKotoeriJapaneseSource(_ sourceID: String) -> Bool {
    let knownPrefixes = [
        "com.apple.inputmethod.Kotoeri.Japanese",
        "com.apple.inputmethod.Kotoeri.KanaTyping.Japanese",
        "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
    ]
    return knownPrefixes.contains { sourceID.hasPrefix($0) }
}

// Detect keyboard type
// Primary detection uses KBGetLayoutType(), which maps LMGetKbdType() to a
// physical layout (kKeyboardJIS/kKeyboardANSI/kKeyboardISO) and is reliable
// across Intel and Apple Silicon Macs.
func isJISKeyboard() -> Bool {
    let keyboardType = LMGetKbdType()
    let layoutType = KBGetLayoutType(Int16(keyboardType))

    if layoutType == kKeyboardJIS {
        return true
    } else if layoutType == kKeyboardANSI || layoutType == kKeyboardISO {
        return false
    } else {
        debugLog("[isJISKeyboard] KBGetLayoutType returned unrecognized layout \(layoutType) for kbdType \(keyboardType), falling back")
    }

    // Legacy numeric fallback for older keyboard type reporting
    if keyboardType == 40 || keyboardType == 41 {
        return true
    }

    // Last-resort heuristic: presence of a Kotoeri Japanese input source is a
    // weak signal (it does not strictly require JIS hardware), kept only for
    // the case where the physical layout truly cannot be determined above.
    if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
        for source in sources {
            if let id = inputSourceProperty(source, kTISPropertyInputSourceID), isKotoeriJapaneseSource(id) {
                return true
            }
        }
    }

    debugLog("[isJISKeyboard] Unable to determine keyboard layout (kbdType=\(keyboardType)), defaulting to non-JIS")
    return false
}

// Get the generic input mode ID for a source (nil for plain keyboard layouts)
func getInputModeID(_ source: TISInputSource) -> String? {
    return inputSourceProperty(source, kTISPropertyInputModeID)
}

// Check whether a source produces ASCII characters directly (no IME conversion needed)
func isASCIICapable(_ source: TISInputSource) -> Bool {
    return boolInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable)
}

// Check if an input source is a Japanese kana input mode (Hiragana/Katakana),
// excluding ASCII-capable Roman/Eisu modes even when their ID contains "Japanese"
func isJapaneseIME(_ source: TISInputSource) -> Bool {
    if isASCIICapable(source) {
        return false
    }
    guard let modeID = getInputModeID(source) else {
        return false
    }
    return modeID.contains(".Japanese") || modeID.contains(".Katakana") || modeID.contains(".Hiragana")
}

// Check if an input source is ASCII-capable (English/Roman/Eisu)
func isEnglishIME(_ source: TISInputSource) -> Bool {
    return isASCIICapable(source)
}

// Check whether the currently selected input source is ASCII-capable.
// Used for IME status reporting: any non-ASCII-capable source requires
// composition, so it counts as "IME on" regardless of its ID string.
func isCurrentSourceASCIICapable() -> Bool {
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    return isASCIICapable(current)
}

// Check if an input source can actually be selected via TISSelectInputSource
func isSelectableInputSource(_ source: TISInputSource) -> Bool {
    return boolInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
        && boolInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)
}

// Result of attempting to switch input source
enum InputSourceSwitchResult {
    case success
    case notFound
    case notSelectable
    case switchFailed
}

// Switch to input source by ID, returns the outcome of the attempt
// Also sends appropriate key event to force input mode (English/Japanese)
func switchToInputSource(_ targetID: String, forceInputMode: Bool = true) -> InputSourceSwitchResult {
    guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        debugLog("[switchToInputSource] Failed to get input source list")
        return .notFound
    }

    var foundButNotSelectable = false

    for source in sources {
        guard let id = inputSourceProperty(source, kTISPropertyInputSourceID), id == targetID else {
            continue
        }

        guard isSelectableInputSource(source) else {
            debugLog("[switchToInputSource] Target source \(targetID) found but not selectable (disabled or select-incapable)")
            foundButNotSelectable = true
            continue
        }

        debugLog("[switchToInputSource] Found target source \(targetID), calling TISSelectInputSource")
        let status = TISSelectInputSource(source)
        if status != noErr {
            debugLog("[switchToInputSource] TISSelectInputSource failed with OSStatus \(status) for \(targetID)")
            return .switchFailed
        }

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
            return .switchFailed
        }

        // Force input mode by sending key event (JIS keyboard only)
        if forceInputMode && isJISKeyboard() {
            if isJapaneseIME(source) {
                debugLog("[switchToInputSource] JIS keyboard detected - Sending Kana key to force Hiragana mode")
                sendKey(kVKJISKana)
            } else if isEnglishIME(source) {
                debugLog("[switchToInputSource] JIS keyboard detected - Sending Eisu key to force English mode")
                sendKey(kVKJISEisu)
            }
        } else if forceInputMode && !isJISKeyboard() {
            debugLog("[switchToInputSource] Non-JIS keyboard detected - Skipping key event (not needed)")
        }

        return .success
    }

    if foundButNotSelectable {
        return .notSelectable
    }
    debugLog("[switchToInputSource] Target source \(targetID) not found in available sources")
    return .notFound
}

// Build a user-facing error message describing why a switch failed
func switchFailureMessage(_ result: InputSourceSwitchResult, targetID: String) -> String {
    switch result {
    case .success:
        return ""
    case .notFound:
        return "Error: Input source not found: \(targetID)\n"
    case .notSelectable:
        return "Error: Input source found but cannot be selected (disabled or select-incapable): \(targetID)\n"
    case .switchFailed:
        return "Error: Failed to switch to input source: \(targetID)\n"
    }
}

// Write IME ID to slot with secure permissions
func writeToSlot(_ id: String, slot: String, instanceID: String? = nil) throws {
    let slotFile = getSaveFilePath(slot: slot, instanceID: instanceID)
    let path = slotFile.path

    // Create the file with secure permissions before writing, so it never
    // exists with the default (umask-dependent) permissions.
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o600])
    }

    let handle = try FileHandle(forWritingTo: slotFile)
    defer { handle.closeFile() }
    handle.truncateFile(atOffset: 0)
    handle.write(id.data(using: .utf8) ?? Data())

    // Re-assert permissions in case the file already existed with different ones
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
}

// Read IME ID from slot
func readFromSlot(_ slot: String, instanceID: String? = nil) -> String? {
    let slotFile = getSaveFilePath(slot: slot, instanceID: instanceID)
    return try? String(contentsOf: slotFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - File Path Management

// Get save file paths and ensure directory exists.
// instanceID isolates slot files per Neovim instance (see issue #31) to
// prevent concurrent Neovim instances from overwriting each other's IME state.
func getSaveFilePath(slot: String = "current", instanceID: String? = nil) -> URL {
    // Validate slot parameter to prevent path traversal
    let validSlotPattern = "^[a-zA-Z0-9_-]+$"
    guard let regex = try? NSRegularExpression(pattern: validSlotPattern),
          regex.firstMatch(in: slot, range: NSRange(slot.startIndex..., in: slot)) != nil else {
        debugLog("Error: Invalid slot name. Only alphanumeric, underscore, and dash allowed.\n")
        exit(1)
    }

    var fileName = "saved-ime-\(slot)"
    if let instanceID = instanceID, !instanceID.isEmpty {
        // Validate instance ID to prevent path traversal (defense in depth;
        // the Lua caller already sanitizes this value)
        let validInstancePattern = "^[a-zA-Z0-9_.-]+$"
        guard let instanceRegex = try? NSRegularExpression(pattern: validInstancePattern),
              instanceRegex.firstMatch(in: instanceID, range: NSRange(instanceID.startIndex..., in: instanceID)) != nil else {
            debugLog("Error: Invalid instance ID. Only alphanumeric, dot, underscore, and dash allowed.\n")
            exit(1)
        }
        fileName += "-\(instanceID)"
    }
    fileName += ".txt"

    ensureDataDirExists()
    guard FileManager.default.fileExists(atPath: nvimDataDir.path) else {
        debugLog("Error: Failed to create directory \(nvimDataDir.path)\n")
        exit(1)
    }

    return nvimDataDir.appendingPathComponent(fileName)
}

// MARK: - Commands

// Save current input source to slot, then switch to the input source saved in
// restoreFrom. If restoreFrom has no saved value, fallback is used; if fallback
// is also nil, the current input source is left unchanged.
func toggle(saveTo: String, restoreFrom: String, fallback: String?, instanceID: String?) -> Never {
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    debugLog("[DEBUG] toggle(saveTo: \(saveTo)): current=\(currentID)\n")

    do {
        try writeToSlot(currentID, slot: saveTo, instanceID: instanceID)
        debugLog("[DEBUG] toggle(saveTo: \(saveTo)): saved to slot \(saveTo)=\(currentID)\n")
    } catch {
        debugLog("Error: Failed to write slot \(saveTo): \(error.localizedDescription)\n")
        exit(1)
    }

    guard let targetID = readFromSlot(restoreFrom, instanceID: instanceID) ?? fallback else {
        debugLog("[DEBUG] toggle(saveTo: \(saveTo)): no slot \(restoreFrom) and no fallback, staying on current\n")
        exit(0)
    }

    debugLog("[DEBUG] toggle(saveTo: \(saveTo)): target=\(targetID)\n")

    let switchResult = switchToInputSource(targetID)
    if switchResult == .success {
        let actualID = getCurrentInputSourceID()
        debugLog("[DEBUG] toggle(saveTo: \(saveTo)): switched to \(actualID ?? "nil")\n")
        exit(0)
    } else {
        debugLog(switchFailureMessage(switchResult, targetID: targetID))
        exit(1)
    }
}

// Save current input source to slot
func saveCurrentInputSource(to slot: String, instanceID: String?) -> Never {
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    do {
        try writeToSlot(currentID, slot: slot, instanceID: instanceID)
        exit(0)
    } catch {
        debugLog("Error: Failed to write slot \(slot): \(error.localizedDescription)\n")
        exit(1)
    }
}

guard CommandLine.arguments.count > 1 else {
    // No argument: get current input source
    if let id = getCurrentInputSourceID() {
        print(id)
    }
    exit(0)
}

let command = CommandLine.arguments[1]
// Optional instance identifier (v:servername or PID) that isolates slot
// files between concurrently running Neovim instances (see issue #31)
let instanceID: String? = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

if command == "keyboard-info" {
    // Diagnostic: print keyboard layout detection details for manual verification
    let keyboardType = LMGetKbdType()
    let layoutType = KBGetLayoutType(Int16(keyboardType))
    print("kbdType=\(keyboardType) layoutType=\(layoutType) isJISKeyboard=\(isJISKeyboard())")
} else if command == "list" {
    // List all selectable input sources
    if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
        for source in sources {
            guard let id = inputSourceProperty(source, kTISPropertyInputSourceID) else {
                continue
            }
            if let name = inputSourceProperty(source, kTISPropertyLocalizedName) {
                print("\(id) - \(name)")
            } else {
                print(id)
            }
        }
    }
} else if command == "status" {
    // Report whether the current input source is engaged in IME (non-ASCII) mode.
    // Determined via kTISPropertyInputSourceIsASCIICapable, not ID string matching.
    print(isCurrentSourceASCIICapable() ? "off" : "on")
    exit(0)
} else if command == "toggle-from-insert" {
    // Toggle from Insert mode: save current to slot A, switch to slot B.
    // No fallback: if slot B is empty, stay on the current input source.
    toggle(saveTo: "a", restoreFrom: "b", fallback: nil, instanceID: instanceID)

} else if command == "toggle-from-normal" {
    // Toggle from Normal mode: save current to slot B, switch to slot A.
    // No fallback: if slot A is empty, stay on the current input source.
    toggle(saveTo: "b", restoreFrom: "a", fallback: nil, instanceID: instanceID)

} else if command == "toggle" {
    // Toggle between two saved IME states
    guard let currentID = getCurrentInputSourceID() else {
        debugLog("Error: Failed to get current input source\n")
        exit(1)
    }

    // Load slot A and B
    let slotAID = readFromSlot("a", instanceID: instanceID)
    let slotBID = readFromSlot("b", instanceID: instanceID)

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
            try writeToSlot(currentID, slot: "b", instanceID: instanceID)
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

    let switchResult = switchToInputSource(target)
    if switchResult == .success {
        exit(0)
    } else {
        debugLog(switchFailureMessage(switchResult, targetID: target))
        exit(1)
    }
} else if command == "save-insert" {
    // Save current input source to slot A (insert mode IME)
    saveCurrentInputSource(to: "a", instanceID: instanceID)

} else if command == "save-normal" {
    // Save current input source to slot B (normal mode IME)
    saveCurrentInputSource(to: "b", instanceID: instanceID)

} else {
    // Legacy: Switch to specified input source
    let switchResult = switchToInputSource(command)
    if switchResult == .success {
        exit(0)
    } else {
        debugLog(switchFailureMessage(switchResult, targetID: command))
        exit(1)
    }
}
