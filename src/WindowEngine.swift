import AppKit
import Foundation
import CoreGraphics

public final class WindowEngine: ObservableObject {
    public static let shared = WindowEngine()
    
    @Published public private(set) var windowList: [WindowItem] = []
    @Published public var selectedIndex: Int = 0
    
    private var iconCache: [String: NSImage] = [:]
    private var titleCache: [CGWindowID: String] = [:]
    private var mruWindowIDs: [CGWindowID] = []
    
    private init() {
        self.mruWindowIDs = SettingsManager.shared.loadSavedMRUWindowIDs()
        setupFocusMonitoring()
    }
    
    private func setupFocusMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func handleAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        // Push top window of this app to MRU head
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            if let topWinID = self.getTopWindowID(forPID: app.processIdentifier) {
                self.recordWindowFocus(windowID: topWinID)
            }
        }
    }
    
    public func recordWindowFocus(windowID: CGWindowID) {
        mruWindowIDs.removeAll(where: { $0 == windowID })
        mruWindowIDs.insert(windowID, at: 0)
        if mruWindowIDs.count > 100 {
            mruWindowIDs.removeLast()
        }
    }
    
    public func refreshWindows() {
        let excluded = SettingsManager.shared.excludedBundleIDs
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            self.windowList = []
            return
        }
        
        struct Candidate {
            let windowID: CGWindowID
            let pid: pid_t
            let ownerName: String
            let bundleID: String
            let runningApp: NSRunningApplication?
            var title: String
        }
        
        var candidates: [Candidate] = []
        var pidsNeedingAX = Set<pid_t>()
        var activeWindowIDs = Set<CGWindowID>()
        
        for info in windowInfoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let width = boundsDict["Width"] as? Double, width >= 120,
                  let height = boundsDict["Height"] as? Double, height >= 120,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = info[kCGWindowOwnerName as String] as? String
            else { continue }
            
            // Exclude system services and FastTab itself
            if ownerName == "Dock" ||
               ownerName == "Window Server" ||
               ownerName == "Control Center" ||
               ownerName == "Notification Center" ||
               ownerName == "SystemUIServer" ||
               ownerName == "Tabby" ||
               ownerName == "FastTab" ||
               ownerName == "WindowManager" {
                continue
            }
            
            let runningApp = NSRunningApplication(processIdentifier: pid)
            let bundleID = runningApp?.bundleIdentifier ?? ""
            
            if bundleID == "com.apple.dock" ||
               bundleID == "com.apple.finder.desktop" ||
               bundleID == "com.dinhbinh.Tabby" ||
               bundleID == "com.dinhbinh.FastTab" ||
               excluded.contains(bundleID) ||
               excluded.contains(ownerName) {
                continue
            }
            
            activeWindowIDs.insert(windowID)
            let rawTitle = (info[kCGWindowName as String] as? String) ?? ""
            
            // If cached or already has rawTitle, use it without AX IPC overhead
            let finalTitle = titleCache[windowID] ?? rawTitle
            
            candidates.append(Candidate(
                windowID: windowID,
                pid: pid,
                ownerName: ownerName,
                bundleID: bundleID,
                runningApp: runningApp,
                title: finalTitle
            ))
            
            if finalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pidsNeedingAX.insert(pid)
            }
        }
        
        // Clean up titleCache for closed windows to prevent memory bloat
        if titleCache.count > 150 {
            titleCache = titleCache.filter { activeWindowIDs.contains($0.key) }
        }
        
        // Fetch missing titles via fast AX only for apps that actually need it
        if !pidsNeedingAX.isEmpty {
            let axTitles = fetchAXTitles(for: pidsNeedingAX)
            for i in 0..<candidates.count {
                let wID = candidates[i].windowID
                if let axTitle = axTitles[wID], !axTitle.isEmpty {
                    candidates[i].title = axTitle
                    titleCache[wID] = axTitle
                }
            }
        }
        
        // Build ordered list preserving the natural macOS WindowServer Z-order
        var ordered: [WindowItem] = []
        for c in candidates {
            var realTitle = c.title
            if realTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                realTitle = c.ownerName
            }
            
            let icon = getIcon(for: c.runningApp, bundleID: c.bundleID, appName: c.ownerName)
            let item = WindowItem(
                id: c.windowID,
                ownerPID: c.pid,
                appName: c.ownerName,
                bundleIdentifier: c.bundleID,
                title: realTitle,
                icon: icon
            )
            ordered.append(item)
        }
        
        self.windowList = Array(ordered.prefix(10))
        self.selectedIndex = self.windowList.count > 1 ? 1 : 0
    }
    
    private func fetchAXTitles(for pids: Set<pid_t>) -> [CGWindowID: String] {
        var titles: [CGWindowID: String] = [:]
        for pid in pids {
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.015) // Ultra-fast 15ms timeout
            var windowsValue: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
               let axWindows = windowsValue as? [AXUIElement] {
                for axWindow in axWindows {
                    var winID: CGWindowID = 0
                    if _AXUIElementGetWindow(axWindow, &winID) == .success {
                        var titleValue: AnyObject?
                        if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
                           let t = titleValue as? String, !t.isEmpty {
                            titles[winID] = t
                        }
                    }
                }
            }
        }
        return titles
    }
    
    private func getIcon(for app: NSRunningApplication?, bundleID: String, appName: String) -> NSImage? {
        let key = bundleID.isEmpty ? appName : bundleID
        if let icon = iconCache[key] {
            return icon
        }
        if let app = app, let icon = app.icon {
            iconCache[key] = icon
            return icon
        }
        if !bundleID.isEmpty, let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: path.path)
            iconCache[key] = icon
            return icon
        }
        return nil
    }
    
    private func getTopWindowID(forPID pid: pid_t) -> CGWindowID? {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            return windowID
        }
        return nil
    }
    
    // Switch to selected window with 0ms latency
    public func commitSwitch() {
        guard selectedIndex >= 0, selectedIndex < windowList.count else { return }
        let selectedItem = windowList[selectedIndex]
        
        recordWindowFocus(windowID: selectedItem.id)
        
        // Activate running app instantly
        if let app = NSRunningApplication(processIdentifier: selectedItem.ownerPID) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        
        // Raise target window via AXUIElement
        DispatchQueue.global(qos: .userInteractive).async {
            self.focusWindowViaAX(item: selectedItem)
        }
    }
    
    private func focusWindowViaAX(item: WindowItem) {
        let appElement = AXUIElementCreateApplication(item.ownerPID)
        var windowListValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListValue)
        
        if result == .success, let axWindows = windowListValue as? [AXUIElement] {
            for axWindow in axWindows {
                var windowIDValue: CGWindowID = 0
                if _AXUIElementGetWindow(axWindow, &windowIDValue) == .success, windowIDValue == item.id {
                    AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
                    AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, axWindow)
                    break
                }
            }
        }
    }
    
    // Close Window (Cmd+W)
    public func closeCurrentWindow() {
        guard selectedIndex >= 0, selectedIndex < windowList.count else { return }
        let item = windowList[selectedIndex]
        
        DispatchQueue.global(qos: .userInteractive).async {
            let appElement = AXUIElementCreateApplication(item.ownerPID)
            var windowListValue: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListValue) == .success,
               let axWindows = windowListValue as? [AXUIElement] {
                for axWindow in axWindows {
                    var windowIDValue: CGWindowID = 0
                    if _AXUIElementGetWindow(axWindow, &windowIDValue) == .success, windowIDValue == item.id {
                        var closeButton: AnyObject?
                        if AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
                           let button = closeButton {
                            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
                        }
                        break
                    }
                }
            }
        }
        
        mruWindowIDs.removeAll(where: { $0 == item.id })
        windowList.remove(at: selectedIndex)
        if selectedIndex >= windowList.count {
            selectedIndex = max(0, windowList.count - 1)
        }
    }
    
    // Quit App (Cmd+Q)
    public func quitCurrentApp() {
        guard selectedIndex >= 0, selectedIndex < windowList.count else { return }
        let item = windowList[selectedIndex]
        
        if let app = NSRunningApplication(processIdentifier: item.ownerPID) {
            app.terminate()
        }
        
        let removedPID = item.ownerPID
        windowList.removeAll(where: { $0.ownerPID == removedPID })
        if selectedIndex >= windowList.count {
            selectedIndex = max(0, windowList.count - 1)
        }
    }
}

// Private C-bridge declaration for AXUIElement
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError
