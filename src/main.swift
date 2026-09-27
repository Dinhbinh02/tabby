import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var pauseMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar accessory app)
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        checkAndRequestAccessibility()
        
        // Start Global Event Tap
        EventTapManager.shared.start()
        
        // Listen to shortcut changes from Settings
        SettingsManager.shared.onShortcutChanged = { _ in
            EventTapManager.shared.start()
        }
        
        // Listen to pause state changes
        SettingsManager.shared.onPauseStateChanged = { [weak self] isPaused in
            self?.updatePauseMenuTitle(isPaused: isPaused)
        }
        
        // Check for updates asynchronously on startup
        SoftwareUpdater.shared.checkOnStartup()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        if #available(macOS 13.0, *) {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "Tabby")
        } else {
            button.title = "⇥"
        }
        
        let menu = NSMenu()
        
        // 1. Show Switcher
        let showItem = NSMenuItem(title: "Show Switcher", action: #selector(showSwitcherHUD), keyEquivalent: "")
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())
        
        // 2. Pause / Resume Tabby
        let pauseItem = NSMenuItem(title: SettingsManager.shared.isPaused ? "Resume Tabby" : "Pause Tabby", action: #selector(togglePause), keyEquivalent: "")
        self.pauseMenuItem = pauseItem
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem.separator())
        
        // 3. Updates & Settings
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        // 4. Restart & Quit
        menu.addItem(NSMenuItem(title: "Restart Tabby", action: #selector(restartApp), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit Tabby", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func showSwitcherHUD() {
        WindowEngine.shared.refreshWindows()
        if !WindowEngine.shared.windowList.isEmpty {
            OverlayPanel.shared.show()
        }
    }
    
    @objc func togglePause() {
        SettingsManager.shared.isPaused.toggle()
        updatePauseMenuTitle(isPaused: SettingsManager.shared.isPaused)
    }
    
    private func updatePauseMenuTitle(isPaused: Bool) {
        pauseMenuItem?.title = isPaused ? "Resume Tabby" : "Pause Tabby"
        if #available(macOS 13.0, *) {
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: isPaused ? "pause.circle" : "macwindow.on.rectangle", accessibilityDescription: "Tabby")
            }
        }
    }
    
    @objc func checkForUpdates() {
        SoftwareUpdater.shared.checkForUpdates(isUserInitiated: true)
    }
    
    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/dinhbinh02/tabby") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func restartApp() {
        SoftwareUpdater.relaunchApp()
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                panes: [
                    SettingsWindowController.Pane(
                        identifier: NSToolbarItem.Identifier("general"),
                        title: "General",
                        toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")!
                    ) {
                        AnyView(GeneralSettingsPane())
                    },
                    SettingsWindowController.Pane(
                        identifier: NSToolbarItem.Identifier("ignore"),
                        title: "Ignore",
                        toolbarIcon: NSImage(systemSymbolName: "nosign", accessibilityDescription: "Ignore")!
                    ) {
                        AnyView(IgnoreSettingsPane())
                    },
                    SettingsWindowController.Pane(
                        identifier: NSToolbarItem.Identifier("about"),
                        title: "About",
                        toolbarIcon: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")!
                    ) {
                        AnyView(AboutSettingsPane())
                    }
                ]
            )
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        EventTapManager.shared.stop()
        NSApp.terminate(nil)
    }
    
    private func checkAndRequestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSLog("[Tabby] Accessibility permission is required for window switching.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                PermissionWindowController.shared.showWindow(nil)
                PermissionWindowController.shared.window?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// Main execution entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
