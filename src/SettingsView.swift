import SwiftUI
import AppKit
import Foundation

// MARK: - Maccy-Style Settings Container & Section
public struct SettingsContainer<Content: View>: View {
    public let contentWidth: CGFloat
    @ViewBuilder public let content: () -> Content
    
    public init(contentWidth: CGFloat = 460, @ViewBuilder content: @escaping () -> Content) {
        self.contentWidth = contentWidth
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(24)
        .frame(width: contentWidth, alignment: .topLeading)
    }
}

public struct SettingsSection<Content: View>: View {
    public let title: String
    public let bottomDivider: Bool
    @ViewBuilder public let content: () -> Content
    
    public init(title: String = "", bottomDivider: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.bottomDivider = bottomDivider
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13))
                        .frame(width: 100, alignment: .trailing)
                        .padding(.top, 4)
                } else {
                    Spacer().frame(width: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if bottomDivider {
                Divider()
                    .padding(.top, 6)
            }
        }
    }
}

// MARK: - General Settings Pane (Matching Maccy GeneralSettingsPane)
public struct GeneralSettingsPane: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    
    public init() {}
    
    public var body: some View {
        SettingsContainer(contentWidth: 470) {
            // Startup & Updates section
            SettingsSection(title: "", bottomDivider: false) {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Toggle("Automatically check for updates", isOn: $settings.automaticallyChecksForUpdates)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Button("Check for Updates...") {
                    SoftwareUpdater.shared.checkForUpdates(isUserInitiated: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
                
                HStack(spacing: 8) {
                    if isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility Granted")
                            .font(.system(size: 13))
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Accessibility Required")
                            .font(.system(size: 13))
                        
                        Button("Setup Permission...") {
                            PermissionWindowController.shared.showWindow(nil)
                            PermissionWindowController.shared.window?.makeKeyAndOrderFront(nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
            
            // Shortcut Section
            SettingsSection(title: "Next window:", bottomDivider: false) {
                ShortcutRecorderView(config: $settings.forwardShortcut, defaultConfig: .defaultCmdTab)
            }
            
            SettingsSection(title: "Previous window:", bottomDivider: false) {
                ShortcutRecorderView(config: $settings.backwardShortcut, defaultConfig: .defaultCmdShiftTab)
            }
            
            // Appearance Section
            SettingsSection(title: "Appearance:", bottomDivider: false) {
                Picker("", selection: $settings.appearance) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }
        }
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
        }
    }
}

// MARK: - Ignore Settings Pane (Matching Maccy IgnoreApplicationsSettingsView)
public struct IgnoreSettingsPane: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedAppID: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let list = Array(settings.excludedBundleIDs).sorted()
            
            List(selection: $selectedAppID) {
                ForEach(list, id: \.self) { item in
                    let ws = NSWorkspace.shared
                    let url = ws.urlForApplication(withBundleIdentifier: item)
                    let running = ws.runningApplications.first(where: { $0.bundleIdentifier == item || $0.localizedName == item })
                    let icon = url.map { ws.icon(forFile: $0.path) } ?? running?.icon
                    let name = url?.deletingPathExtension().lastPathComponent ?? (running?.localizedName ?? item)
                    
                    HStack(spacing: 10) {
                        if let icon = icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "app.dashed")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.system(size: 13, weight: .medium))
                            Text(item)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(item)
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .frame(width: 440, height: 200)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            
            HStack {
                ControlGroup {
                    Button(action: openApplicationPicker) {
                        Image(systemName: "plus")
                    }
                    Button(action: removeSelected) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedAppID == nil)
                }
                .frame(width: 60)
                
                Spacer()
            }
            
            Text("Windows from excluded applications will never appear in the switcher HUD.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 470, alignment: .topLeading)
    }
    
    private func openApplicationPicker() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        
        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url),
               let bid = bundle.bundleIdentifier {
                settings.excludedBundleIDs.insert(bid)
            } else {
                let appName = url.deletingPathExtension().lastPathComponent
                settings.excludedBundleIDs.insert(appName)
            }
        }
    }
    
    private func removeSelected() {
        guard let id = selectedAppID else { return }
        settings.excludedBundleIDs.remove(id)
        selectedAppID = nil
    }
}

// MARK: - About Settings Pane
public struct AboutSettingsPane: View {
    @ObservedObject var settings = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)
            
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "macwindow.on.rectangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 4) {
                Text("Tabby")
                    .font(.system(size: 20, weight: .bold))
                
                Text("Version \(SoftwareUpdater.shared.currentVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text("A lightweight, blazing-fast window switcher for macOS.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Check for Updates...") {
                    SoftwareUpdater.shared.checkForUpdates(isUserInitiated: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Reset Defaults") {
                    settings.forwardShortcut = .defaultCmdTab
                    settings.backwardShortcut = .defaultCmdShiftTab
                    settings.excludedBundleIDs = []
                    settings.appearance = .system
                    settings.launchAtLogin = false
                    settings.automaticallyChecksForUpdates = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.bottom, 6)
        }
        .padding(24)
        .frame(width: 470, height: 260)
    }
}
