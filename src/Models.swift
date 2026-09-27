import AppKit
import Foundation
import Carbon.HIToolbox

public struct WindowItem: Identifiable, Equatable {
    public let id: CGWindowID
    public let ownerPID: pid_t
    public let appName: String
    public let bundleIdentifier: String?
    public var title: String
    public let icon: NSImage?
    
    public static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        return lhs.id == rhs.id
    }
}

public struct ShortcutConfig: Codable, Equatable {
    public var keyCode: UInt16
    public var carbonModifiers: UInt32 // e.g. cmdKey, optionKey, controlKey, shiftKey
    public var keyDisplay: String
    
    public static let defaultCmdTab = ShortcutConfig(
        keyCode: 48, // Tab key
        carbonModifiers: UInt32(cmdKey),
        keyDisplay: "Tab"
    )
    
    public static let defaultCmdShiftTab = ShortcutConfig(
        keyCode: 48, // Tab key
        carbonModifiers: UInt32(cmdKey | shiftKey),
        keyDisplay: "Tab"
    )
    
    public var displayString: String {
        var str = ""
        if carbonModifiers & UInt32(controlKey) != 0 { str += "⌃ " }
        if carbonModifiers & UInt32(optionKey) != 0 { str += "⌥ " }
        if carbonModifiers & UInt32(shiftKey) != 0 { str += "⇧ " }
        if carbonModifiers & UInt32(cmdKey) != 0 { str += "⌘ " }
        str += keyDisplay
        return str
    }
}

public func keycodeToString(_ keyCode: UInt16) -> String {
    switch keyCode {
    case 48: return "Tab"
    case 49: return "Space"
    case 36: return "Return"
    case 53: return "Esc"
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 23: return "5"
    case 22: return "6"
    case 26: return "7"
    case 28: return "8"
    case 25: return "9"
    case 29: return "0"
    case 31: return "O"
    case 34: return "I"
    case 35: return "P"
    case 37: return "L"
    case 38: return "J"
    case 40: return "K"
    case 45: return "N"
    case 46: return "M"
    case 50: return "`"
    default: return "Key \(keyCode)"
    }
}

