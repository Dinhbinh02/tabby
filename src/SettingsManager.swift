import Foundation
import CoreGraphics
import ServiceManagement
import Combine

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }
}

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let kShortcutKey = "Tabby_ShortcutConfig"
    private let kExcludedAppsKey = "Tabby_ExcludedApps"
    private let kLaunchAtLoginKey = "Tabby_LaunchAtLogin"
    private let kWindowHistoryKey = "Tabby_WindowHistory"
    private let kAppearanceKey = "Tabby_AppearanceMode"
    private let kAutoUpdateKey = "Tabby_AutoUpdate"
    private let kIsPausedKey = "Tabby_IsPaused"
    
    @Published public var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: kAppearanceKey)
        }
    }
    
    @Published public var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: kIsPausedKey)
            onPauseStateChanged?(isPaused)
        }
    }
    
    @Published public var automaticallyChecksForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(automaticallyChecksForUpdates, forKey: kAutoUpdateKey)
        }
    }
    
    @Published public var shortcut: ShortcutConfig {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: kShortcutKey)
            }
            onShortcutChanged?(shortcut)
        }
    }
    
    @Published public var excludedBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedBundleIDs), forKey: kExcludedAppsKey)
            onExcludedAppsChanged?()
        }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: kLaunchAtLoginKey)
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    
    public var onShortcutChanged: ((ShortcutConfig) -> Void)?
    public var onExcludedAppsChanged: (() -> Void)?
    public var onPauseStateChanged: ((Bool) -> Void)?
    
    private init() {
        // Load isPaused
        self.isPaused = UserDefaults.standard.bool(forKey: kIsPausedKey)
        
        // Load auto update
        if UserDefaults.standard.object(forKey: kAutoUpdateKey) != nil {
            self.automaticallyChecksForUpdates = UserDefaults.standard.bool(forKey: kAutoUpdateKey)
        } else {
            self.automaticallyChecksForUpdates = true
        }
        
        // Load appearance
        if let savedApp = UserDefaults.standard.string(forKey: kAppearanceKey),
           let mode = AppearanceMode(rawValue: savedApp) {
            self.appearance = mode
        } else {
            self.appearance = .system
        }
        
        // Load shortcut
        if let data = UserDefaults.standard.data(forKey: kShortcutKey),
           let saved = try? JSONDecoder().decode(ShortcutConfig.self, from: data) {
            self.shortcut = saved
        } else {
            self.shortcut = .defaultCmdTab
        }
        
        // Load excluded apps
        if let saved = UserDefaults.standard.stringArray(forKey: kExcludedAppsKey) {
            let filtered = saved.filter {
                $0 != "com.apple.dock" &&
                $0 != "com.apple.finder.desktop" &&
                $0 != "com.dinhbinh.Tabby" &&
                $0 != "com.dinhbinh.FastTab"
            }
            self.excludedBundleIDs = Set(filtered)
        } else {
            self.excludedBundleIDs = []
        }
        
        // Launch at login
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = UserDefaults.standard.bool(forKey: kLaunchAtLoginKey)
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[Tabby] Failed to update launch at login: \(error)")
            }
        }
    }
    
    // MRU history persistence
    public func loadSavedMRUWindowIDs() -> [CGWindowID] {
        guard let saved = UserDefaults.standard.array(forKey: kWindowHistoryKey) as? [UInt32] else {
            return []
        }
        return saved
    }
    
    public func saveMRUWindowIDs(_ ids: [CGWindowID]) {
        let maxIDs = Array(ids.prefix(50))
        UserDefaults.standard.set(maxIDs, forKey: kWindowHistoryKey)
    }
}
