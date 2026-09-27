import SwiftUI
import AppKit
import Carbon.HIToolbox

public struct ShortcutRecorderView: View {
    @Binding var config: ShortcutConfig
    public var defaultConfig: ShortcutConfig
    @State private var isRecording = false
    @State private var monitor: Any?
    
    public init(config: Binding<ShortcutConfig>, defaultConfig: ShortcutConfig = .defaultCmdTab) {
        self._config = config
        self.defaultConfig = defaultConfig
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 4) {
                    Spacer(minLength: 4)
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.small)
                        Text("Type shortcut...")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    } else {
                        Text(config.displayString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer(minLength: 4)
                    
                    if !isRecording && config != defaultConfig {
                        Button(action: {
                            config = defaultConfig
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(width: 140, height: 26)
                .background(
                    Capsule()
                        .fill(isRecording ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // 1. Intercept system-level shortcuts like Cmd+Tab via EventTapManager
        EventTapManager.shared.isRecordingShortcut = true
        EventTapManager.shared.onShortcutRecorded = { newConfig in
            self.config = newConfig
            self.stopRecording()
        }
        
        // 2. Also monitor local events
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // ESC
                self.stopRecording()
                return nil
            }
            
            var carbonFlags: UInt32 = 0
            if event.modifierFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
            if event.modifierFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
            
            if carbonFlags == 0 {
                return nil
            }
            
            let keyStr = keycodeToString(event.keyCode)
            self.config = ShortcutConfig(
                keyCode: event.keyCode,
                carbonModifiers: carbonFlags,
                keyDisplay: keyStr
            )
            
            self.stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        EventTapManager.shared.isRecordingShortcut = false
        EventTapManager.shared.onShortcutRecorded = nil
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
    
    private func keycodeToString(_ keyCode: UInt16) -> String {
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
}
