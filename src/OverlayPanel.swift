import SwiftUI
import AppKit

public struct SwitcherHUDView: View {
    @ObservedObject var engine = WindowEngine.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.colorScheme) var systemColorScheme
    
    public init() {}
    
    private var isDark: Bool {
        switch settings.appearance {
        case .system:
            return systemColorScheme == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(engine.windowList.enumerated()), id: \.element.id) { index, item in
                let isSelected = (index == engine.selectedIndex)
                
                HStack(spacing: 12) {
                    // App Icon
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .shadow(color: Color.black.opacity(isDark ? 0.3 : 0.15), radius: 2, x: 0, y: 1)
                    } else {
                        Image(systemName: "app.dashed")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(isDark ? .gray : .secondary)
                    }
                    
                    // Window Title
                    Text(item.title.isEmpty ? item.appName : item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundColor(
                            isSelected
                                ? (isDark ? Color.white : Color.white)
                                : (isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.85))
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    isDark ?
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.05, green: 0.45, blue: 1.0).opacity(0.45),
                                            Color(red: 0.0, green: 0.35, blue: 0.9).opacity(0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.88),
                                            Color(red: 0.0, green: 0.40, blue: 0.95).opacity(0.92)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            isDark ?
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.3, green: 0.65, blue: 1.0).opacity(0.8),
                                                    Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.4)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.45),
                                                    Color.white.opacity(0.15)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.2
                                        )
                                )
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.selectedIndex = index
                    EventTapManager.shared.commitAndCloseSession()
                }
            }
        }
        .padding(10)
        .frame(width: 440)
        .background(
            ZStack {
                // Liquid Glass Backing
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, isDark ? .dark : .light)
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDark ? Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.85) : Color(red: 0.96, green: 0.96, blue: 0.98).opacity(0.82))
                
                // Specular Glass Border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isDark ? [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ] : [
                                Color.white.opacity(0.85),
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

public final class OverlayPanel: NSPanel {
    public static let shared = OverlayPanel()
    private var outsideClickMonitor: Any?
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver
        self.animationBehavior = .none
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        
        let hostingView = NSHostingView(rootView: SwitcherHUDView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
    
    public func show() {
        guard let screen = NSScreen.main else { return }
        
        if let hosting = self.contentView as? NSHostingView<SwitcherHUDView> {
            let fitting = hosting.fittingSize
            self.setContentSize(fitting)
            
            let screenFrame = screen.frame
            let x = screenFrame.origin.x + (screenFrame.width - fitting.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - fitting.height) / 2
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.orderFrontRegardless()
        
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                guard let self = self, self.isVisible else { return }
                let mouseLoc = NSEvent.mouseLocation
                if !self.frame.contains(mouseLoc) {
                    EventTapManager.shared.cancelSession()
                }
            }
        }
    }
    
    public func hide() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        self.orderOut(nil)
    }
}
