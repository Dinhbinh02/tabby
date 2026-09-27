import AppKit
import CoreGraphics
import Carbon.HIToolbox

public final class EventTapManager {
    public static let shared = EventTapManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var isSessionActive = false
    private var isModifierHeld = false
    private var hudShowWorkItem: DispatchWorkItem?
    
    public var isRecordingShortcut: Bool = false
    public var onShortcutRecorded: ((ShortcutConfig) -> Void)?
    
    private init() {}
    
    public func start() {
        stop()
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.keyUp.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)
        
        // Use .cghidEventTap to intercept system hotkeys like Cmd+Tab before WindowServer
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[Tabby] Failed to create .cghidEventTap. Retrying with .cgSessionEventTap...")
            startFallbackSessionTap()
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[Tabby] Event tap started successfully with .cghidEventTap")
    }
    
    private func startFallbackSessionTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                     (1 << CGEventType.keyUp.rawValue) |
                                     (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[Tabby] All event taps failed. Please check Accessibility permissions.")
            return
        }
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        // If user paused Tabby, pass all keyboard events through immediately
        if SettingsManager.shared.isPaused && !isRecordingShortcut {
            return Unmanaged.passRetained(event)
        }
        
        let flags = event.flags
        
        // 0. Intercept keys while user is recording in Settings
        if isRecordingShortcut {
            if type == .keyDown {
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == 53 { // ESC cancels recording
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecordingShortcut = false
                    }
                    return nil
                }
                
                var carbonFlags: UInt32 = 0
                if flags.contains(.maskCommand) { carbonFlags |= UInt32(cmdKey) }
                if flags.contains(.maskAlternate) { carbonFlags |= UInt32(optionKey) }
                if flags.contains(.maskControl) { carbonFlags |= UInt32(controlKey) }
                if flags.contains(.maskShift) { carbonFlags |= UInt32(shiftKey) }
                
                if carbonFlags != 0 {
                    let keyStr = keycodeToString(keyCode)
                    let newConfig = ShortcutConfig(keyCode: keyCode, carbonModifiers: carbonFlags, keyDisplay: keyStr)
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecordingShortcut = false
                        self?.onShortcutRecorded?(newConfig)
                    }
                    return nil // Swallows Cmd+Tab completely so macOS doesn't switch apps!
                }
            } else if type == .flagsChanged || type == .keyUp {
                return nil
            }
            return nil
        }
        
        let forwardShortcut = SettingsManager.shared.forwardShortcut
        let backwardShortcut = SettingsManager.shared.backwardShortcut
        
        let forwardMask = carbonToCGFlags(forwardShortcut.carbonModifiers)
        let backwardMask = carbonToCGFlags(backwardShortcut.carbonModifiers)
        let anyRequiredModifiers = forwardMask.union(backwardMask)
        
        // 1. Handle Modifier Key Releases (Commit Switch)
        if type == .flagsChanged {
            let modifierActive = (flags.rawValue & anyRequiredModifiers.rawValue) != 0
            
            if !modifierActive && isModifierHeld {
                isModifierHeld = false
                if isSessionActive {
                    commitAndCloseSession()
                }
            }
            return Unmanaged.passRetained(event)
        }
        
        // 2. Handle Key Down
        if type == .keyDown {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isBackwardTrigger = (keyCode == backwardShortcut.keyCode && modifiersMatch(eventFlags: flags, requiredFlags: backwardMask))
            let isForwardTrigger = (keyCode == forwardShortcut.keyCode && modifiersMatch(eventFlags: flags, requiredFlags: forwardMask))
            
            // Trigger Hotkey matched
            if isBackwardTrigger || isForwardTrigger {
                isModifierHeld = true
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if !self.isSessionActive {
                        self.isSessionActive = true
                        WindowEngine.shared.refreshWindows()
                        
                        let count = WindowEngine.shared.windowList.count
                        if count == 0 {
                            self.isSessionActive = false
                            return
                        }
                        
                        if isBackwardTrigger && count > 1 {
                            WindowEngine.shared.selectedIndex = count - 1
                        } else if count > 1 {
                            WindowEngine.shared.selectedIndex = 1
                        } else {
                            WindowEngine.shared.selectedIndex = 0
                        }
                        
                        // Debounce popup: Only show HUD if modifier is held for > 100ms
                        self.hudShowWorkItem?.cancel()
                        let workItem = DispatchWorkItem { [weak self] in
                            guard let self = self, self.isSessionActive, self.isModifierHeld else { return }
                            OverlayPanel.shared.show()
                        }
                        self.hudShowWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: workItem)
                    } else {
                        // Already in session: navigate and show immediately
                        let count = WindowEngine.shared.windowList.count
                        if count > 0 {
                            if isBackwardTrigger {
                                WindowEngine.shared.selectedIndex = (WindowEngine.shared.selectedIndex - 1 + count) % count
                            } else {
                                WindowEngine.shared.selectedIndex = (WindowEngine.shared.selectedIndex + 1) % count
                            }
                        }
                        self.hudShowWorkItem?.cancel()
                        OverlayPanel.shared.show()
                    }
                }
                return nil // Suppress event from reaching macOS
            }
            
            // Session Navigation / Actions
            if isSessionActive {
                let count = WindowEngine.shared.windowList.count
                
                switch keyCode {
                case 53: // ESC -> Cancel
                    cancelSession()
                    return nil
                    
                case 36, 49: // Return or Space -> Commit
                    commitAndCloseSession()
                    return nil
                    
                case 13: // W key with Cmd -> Close window
                    if flags.contains(.maskCommand) {
                        DispatchQueue.main.async {
                            WindowEngine.shared.closeCurrentWindow()
                            if WindowEngine.shared.windowList.isEmpty {
                                self.cancelSession()
                            } else {
                                OverlayPanel.shared.show()
                            }
                        }
                        return nil
                    }
                    
                case 12: // Q key with Cmd -> Quit app
                    if flags.contains(.maskCommand) {
                        DispatchQueue.main.async {
                            WindowEngine.shared.quitCurrentApp()
                            if WindowEngine.shared.windowList.isEmpty {
                                self.cancelSession()
                            } else {
                                OverlayPanel.shared.show()
                            }
                        }
                        return nil
                    }
                    
                case 124, 125: // Right / Down Arrow
                    if count > 0 {
                        DispatchQueue.main.async {
                            WindowEngine.shared.selectedIndex = (WindowEngine.shared.selectedIndex + 1) % count
                            self.hudShowWorkItem?.cancel()
                            OverlayPanel.shared.show()
                        }
                    }
                    return nil
                    
                case 123, 126: // Left / Up Arrow
                    if count > 0 {
                        DispatchQueue.main.async {
                            WindowEngine.shared.selectedIndex = (WindowEngine.shared.selectedIndex - 1 + count) % count
                            self.hudShowWorkItem?.cancel()
                            OverlayPanel.shared.show()
                        }
                    }
                    return nil
                    
                default:
                    break
                }
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    public func commitAndCloseSession() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hudShowWorkItem?.cancel()
            self.hudShowWorkItem = nil
            self.isSessionActive = false
            OverlayPanel.shared.hide()
            WindowEngine.shared.commitSwitch()
        }
    }
    
    public func cancelSession() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hudShowWorkItem?.cancel()
            self.hudShowWorkItem = nil
            self.isSessionActive = false
            self.isModifierHeld = false
            OverlayPanel.shared.hide()
        }
    }
    
    private func carbonToCGFlags(_ carbonModifiers: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        return flags
    }
    
    private func modifiersMatch(eventFlags: CGEventFlags, requiredFlags: CGEventFlags) -> Bool {
        let relevantMasks: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        for mask in relevantMasks {
            let eventHas = eventFlags.contains(mask)
            let requiredHas = requiredFlags.contains(mask)
            if eventHas != requiredHas {
                return false
            }
        }
        return true
    }
}
