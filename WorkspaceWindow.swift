import AppKit
import SwiftUI

final class WorkspaceWindowController: NSWindowController, NSMenuItemValidation, NSWindowDelegate {
    private static let frameName = NSWindow.FrameAutosaveName("QuireWindow")

    private static let defaultSize = NSSize(width: 1180, height: 820)

    private static let fullScreenInset = 8.0

    private let container = WorkspaceViewController()

    convenience init() {
        self.init(window: nil)
        shouldCascadeWindows = false

        let window = NSWindow(contentViewController: container)
        window.title = "Quire"
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unifiedCompact
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 720, height: 520)

        window.setContentSize(Self.defaultSize)
        window.setFrameAutosaveName(Self.frameName)

        if !window.setFrameUsingName(Self.frameName) {
            window.center()
        }
        self.window = window

        let closeButton = window.standardWindowButton(.closeButton)
        closeButton?.target = self
        closeButton?.action = #selector(closeWindow(_:))

        container.stripHeight = max(28, window.frame.height - window.contentLayoutRect.height)
        Workspace.shared.setStripLeadingInset(buttonsInset)
    }

    private var buttonsInset: Double {
        guard let zoomButton = window?.standardWindowButton(.zoomButton) else { return 78 }
        return zoomButton.convert(zoomButton.bounds, to: nil).maxX + 10
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        Workspace.shared.setStripLeadingInset(Self.fullScreenInset)
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        Workspace.shared.setStripLeadingInset(buttonsInset)
    }

    func display(_ tab: WorkspaceTab) {
        let current = document as? NSDocument

        if current !== tab.document {
            current?.removeWindowController(self)
            tab.document?.addWindowController(self)
        }
        if tab.document == nil {
            document = nil
            window?.title = tab.title
        }
        container.show(tab.content)
    }

    func shutWindow() {
        (document as? NSDocument)?.removeWindowController(self)
        document = nil
        container.show(nil)

        if window?.isVisible == true {
            window?.close()
        }
    }

    func close(_ document: QuireDocument) {
        document.canClose(
            withDelegate: self,
            shouldClose: #selector(document(_:shouldClose:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func document(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if shouldClose {
            document.close()
        }
    }

    @objc func closeTab(_ sender: Any?) {
        Workspace.shared.closeSelected()
    }

    @objc func showTab(_ sender: Any?) {
        if let item = sender as? NSMenuItem {
            Workspace.shared.selectTab(at: item.tag)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showTab(_:)) {
            return menuItem.tag < Workspace.shared.tabs.count
        }
        return true
    }

    @objc func closeWindow(_ sender: Any?) {
        NSDocumentController.shared.closeAllDocuments(
            withDelegate: self,
            didCloseAllSelector: #selector(documentController(_:didCloseAll:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func documentController(_ controller: NSDocumentController, didCloseAll: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if didCloseAll {
            Workspace.shared.removeAll()
        }
    }

    override func synchronizeWindowTitleWithDocumentName() {
        super.synchronizeWindowTitleWithDocumentName()
        Workspace.shared.refreshTabs()
    }

    override func setDocumentEdited(_ dirtyFlag: Bool) {
        super.setDocumentEdited(dirtyFlag)
        Workspace.shared.refreshTabs()
    }
}

private final class TabStripHostingView: NSHostingView<TabStrip> {
    override var mouseDownCanMoveWindow: Bool { false }
}

final class WorkspaceViewController: NSViewController {
    private let content = NSView()
    private var shown: NSViewController?
    private var stripHeightConstraint: NSLayoutConstraint?

    var stripHeight = 28.0 {
        didSet { stripHeightConstraint?.constant = stripHeight }
    }

    override func loadView() {
        let strip = TabStripHostingView(rootView: TabStrip(workspace: .shared))
        strip.sizingOptions = []
        strip.safeAreaRegions = []
        strip.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(strip)
        root.addSubview(content)

        let height = strip.heightAnchor.constraint(equalToConstant: stripHeight)
        stripHeightConstraint = height

        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: root.topAnchor),
            strip.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            height,

            content.topAnchor.constraint(equalTo: strip.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }

    func show(_ controller: NSViewController?) {
        guard shown !== controller else { return }
        loadViewIfNeeded()

        shown?.view.removeFromSuperview()
        shown?.removeFromParent()
        shown = controller

        guard let controller else { return }
        addChild(controller)
        controller.view.frame = content.bounds
        controller.view.autoresizingMask = [.width, .height]
        content.addSubview(controller.view)
    }
}
