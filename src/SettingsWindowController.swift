import AppKit
import SwiftUI

public final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    public struct Pane {
        public let identifier: NSToolbarItem.Identifier
        public let title: String
        public let toolbarIcon: NSImage
        public let makeView: () -> AnyView
        
        public init(
            identifier: NSToolbarItem.Identifier,
            title: String,
            toolbarIcon: NSImage,
            makeView: @escaping () -> AnyView
        ) {
            self.identifier = identifier
            self.title = title
            self.toolbarIcon = toolbarIcon
            self.makeView = makeView
        }
    }
    
    private let panes: [Pane]
    private var currentPaneIdentifier: NSToolbarItem.Identifier
    
    public init(panes: [Pane]) {
        self.panes = panes
        let firstID = panes.first?.identifier ?? NSToolbarItem.Identifier("general")
        self.currentPaneIdentifier = firstID
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        
        super.init(window: window)
        
        let toolbar = NSToolbar(identifier: "TabbySettingsToolbar")
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        
        window.toolbar = toolbar
        selectPane(identifier: firstID, animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return panes.map { $0.identifier }
    }
    
    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return panes.map { $0.identifier }
    }
    
    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return panes.map { $0.identifier }
    }
    
    public func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = panes.first(where: { $0.identifier == itemIdentifier }) else { return nil }
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.image = pane.toolbarIcon
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }
    
    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        selectPane(identifier: sender.itemIdentifier, animated: true)
    }
    
    public func selectPane(identifier: NSToolbarItem.Identifier, animated: Bool = true) {
        guard let pane = panes.first(where: { $0.identifier == identifier }),
              let window = self.window else { return }
        
        currentPaneIdentifier = identifier
        window.toolbar?.selectedItemIdentifier = identifier
        window.title = pane.title
        
        let hostingView = NSHostingView(rootView: pane.makeView())
        let contentSize = hostingView.fittingSize
        
        let targetWidth: CGFloat = max(480, contentSize.width)
        let targetHeight: CGFloat = max(340, contentSize.height)
        
        let currentFrame = window.frame
        let newContentRect = NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y, width: targetWidth, height: targetHeight)
        let newWindowFrame = window.frameRect(forContentRect: newContentRect)
        let adjustedFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + (currentFrame.height - newWindowFrame.height),
            width: newWindowFrame.width,
            height: newWindowFrame.height
        )
        
        window.contentView = hostingView
        window.setFrame(adjustedFrame, display: true, animate: animated)
    }
}
