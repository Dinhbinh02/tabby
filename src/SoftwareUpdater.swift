import AppKit
import Foundation
import Combine

public struct GitHubRelease: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let assets: [ReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

public struct ReleaseAsset: Codable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

public final class SoftwareUpdater: ObservableObject {
    public static let shared = SoftwareUpdater()
    
    @Published public var isChecking: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var isUpdateAvailable: Bool = false
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var updateStatusMessage: String = ""
    
    private let repoOwner = "dinhbinh02"
    private let repoName = "tabby"
    
    public var currentVersion: String {
        return (Foundation.Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
    
    private init() {}
    
    public func checkOnStartup() {
        guard SettingsManager.shared.automaticallyChecksForUpdates else { return }
        checkForUpdates(isUserInitiated: false)
    }
    
    public func checkForUpdates(isUserInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true
        updateStatusMessage = "Checking for updates..."
        
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Tabby-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                
                if let error = error {
                    self.updateStatusMessage = "Check failed: \(error.localizedDescription)"
                    if isUserInitiated {
                        self.showUpToDateAlert(message: "Could not connect to update server. Please check your network connection.")
                    }
                    return
                }
                
                guard let data = data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                    self.updateStatusMessage = "No releases found."
                    if isUserInitiated {
                        self.showUpToDateAlert(message: "Tabby \(self.currentVersion) is currently the latest version.")
                    }
                    return
                }
                
                let cleanRemoteVersion = release.tagName.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
                let cleanCurrentVersion = self.currentVersion.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
                
                if self.isVersion(cleanRemoteVersion, newerThan: cleanCurrentVersion) {
                    self.latestRelease = release
                    self.isUpdateAvailable = true
                    self.updateStatusMessage = "New version available: \(release.tagName)"
                    self.showUpdateWindow(release: release)
                } else {
                    self.latestRelease = nil
                    self.isUpdateAvailable = false
                    self.updateStatusMessage = "Tabby is up to date (\(self.currentVersion))"
                    if isUserInitiated {
                        self.showUpToDateAlert(message: "You're all up to date!\nTabby \(self.currentVersion) is currently the newest version available.")
                    }
                }
            }
        }.resume()
    }
    
    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }
    
    private func showUpToDateAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    public func showUpdateWindow(release: GitHubRelease) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "A new version of Tabby is available!"
        
        let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Performance improvements and bug fixes."
        alert.informativeText = "Tabby \(release.tagName) is now available (you have \(currentVersion)).\n\nRelease Notes:\n\(notes)"
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "View on GitHub")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // Install Update
            self.downloadAndInstall(release: release)
        case .alertThirdButtonReturn:
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    public func downloadAndInstall(release: GitHubRelease) {
        guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) ?? release.assets.first else {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        guard let downloadUrl = URL(string: dmgAsset.browserDownloadUrl) else { return }
        
        self.isDownloading = true
        self.downloadProgress = 0.0
        
        let tempDir = Foundation.FileManager.default.temporaryDirectory
        let targetFile = tempDir.appendingPathComponent(dmgAsset.name)
        
        try? Foundation.FileManager.default.removeItem(at: targetFile)
        
        let downloadTask = Foundation.URLSession.shared.downloadTask(with: downloadUrl) { [weak self] tempLocation, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showUpToDateAlert(message: "Failed to download update: \(error.localizedDescription)")
                }
                return
            }
            
            guard let tempLocation = tempLocation else {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showUpToDateAlert(message: "Download failed: installer file was empty.")
                }
                return
            }
            
            // Must move file synchronously before the completion handler returns
            do {
                try? Foundation.FileManager.default.removeItem(at: targetFile)
                try Foundation.FileManager.default.moveItem(at: tempLocation, to: targetFile)
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.showUpToDateAlert(message: "Failed to save installer: \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isDownloading = false
                self.mountAndReplaceApp(dmgPath: targetFile.path)
            }
        }
        downloadTask.resume()
    }
    
    private func mountAndReplaceApp(dmgPath: String) {
        let mountPoint = "/Volumes/Tabby_Update_\(UUID().uuidString.prefix(6))"
        let currentAppPath = Foundation.Bundle.main.bundlePath
        let targetApp = currentAppPath.hasSuffix(".app") ? currentAppPath : "/Applications/Tabby.app"
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Mount DMG silently
            let mountProcess = Process()
            mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            mountProcess.arguments = ["attach", dmgPath, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]
            try? mountProcess.run()
            mountProcess.waitUntilExit()
            
            let mountedApp = "\(mountPoint)/Tabby.app"
            
            if Foundation.FileManager.default.fileExists(atPath: mountedApp) {
                let updateScript = """
                sleep 0.8
                killall Tabby 2>/dev/null || true
                rm -rf "\(targetApp)"
                cp -R "\(mountedApp)" "\(targetApp)"
                if [ "\(targetApp)" != "/Applications/Tabby.app" ]; then
                    rm -rf "/Applications/Tabby.app"
                    cp -R "\(mountedApp)" "/Applications/Tabby.app"
                fi
                xattr -cr "\(targetApp)" 2>/dev/null || true
                xattr -cr "/Applications/Tabby.app" 2>/dev/null || true
                hdiutil detach "\(mountPoint)" -quiet 2>/dev/null || true
                rm -f "\(dmgPath)" 2>/dev/null || true
                open "\(targetApp)"
                """
                
                let scriptURL = Foundation.FileManager.default.temporaryDirectory.appendingPathComponent("tabby_relaunch.sh")
                try? updateScript.write(to: scriptURL, atomically: true, encoding: String.Encoding.utf8)
                
                let chmod = Process()
                chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmod.arguments = ["+x", scriptURL.path]
                try? chmod.run()
                chmod.waitUntilExit()
                
                let relaunch = Process()
                relaunch.executableURL = scriptURL
                try? relaunch.run()
                
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            } else {
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", mountPoint, "-quiet"]
                try? detachProcess.run()
                
                DispatchQueue.main.async {
                    self.showUpToDateAlert(message: "Failed to locate Tabby.app inside downloaded DMG installer.")
                }
            }
        }
    }
    
    public static func relaunchApp() {
        let appPath = Foundation.Bundle.main.bundlePath
        let relaunchScript = """
        sleep 0.3
        open "\(appPath)"
        """
        let scriptURL = Foundation.FileManager.default.temporaryDirectory.appendingPathComponent("tabby_restart.sh")
        try? relaunchScript.write(to: scriptURL, atomically: true, encoding: String.Encoding.utf8)
        
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", scriptURL.path]
        try? chmod.run()
        chmod.waitUntilExit()
        
        let restart = Process()
        restart.executableURL = scriptURL
        try? restart.run()
        
        NSApp.terminate(nil)
    }
}
