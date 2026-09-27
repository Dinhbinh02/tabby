import AppKit
import SwiftUI

public struct PermissionView: View {
    @State private var isTrusted: Bool = AXIsProcessTrusted()
    @State private var timer: Timer? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "macwindow.on.rectangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 6) {
                Text("Accessibility Permission Required")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Tabby needs Accessibility permission to detect window lists and switch windows instantly.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            Divider().padding(.horizontal, 20)
            
            if !isTrusted {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))
                        Text("Open Privacy & Security > Accessibility in System Settings.")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))
                        Text("Enable the toggle for Tabby.")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: openAccessibilitySettings) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Open System Settings...")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        Text("Permission granted successfully!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    
                    Text("Please restart Tabby to activate window switching.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        SoftwareUpdater.relaunchApp()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Restart Tabby Now")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(28)
        .frame(width: 440)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                self.isTrusted = trusted
                if trusted {
                    EventTapManager.shared.start()
                }
            }
        }
    }
}

public final class PermissionWindowController: NSWindowController {
    public static let shared = PermissionWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tabby Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PermissionView())
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
