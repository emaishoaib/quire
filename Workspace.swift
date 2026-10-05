//
//  Workspace.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/5/26.
//

import AppKit
import SwiftUI

/// One tab: an open PDF, or the start screen when `document` is nil.
///
/// The tab owns the view controller that draws it, and keeps it for as long as the tab
/// exists. Switching away only takes the view out of the window, so the page being read,
/// the find panel and everything else the view remembers are still there on return.
@Observable
final class WorkspaceTab: Identifiable {
    let id = UUID()
    let document: QuireDocument?
    var title: String

    @ObservationIgnored let content: NSViewController

    var isStart: Bool { document == nil }

    init(document: QuireDocument?, title: String, content: NSViewController) {
        self.document = document
        self.title = title
        self.content = content
    }
}

/// The tabs open in Quire's one window, and which of them is showing.
///
/// Quire draws its own tabs rather than using the ones macOS gives a window, so that
/// their order, look and behaviour are its own. Every PDF therefore shares one window,
/// and this decides what that window shows.
///
/// A new tab always goes last. Opening a PDF also drops any start tab: the start screen
/// exists to open something, so once something is open it has done its job.
@Observable
final class Workspace {
    static let shared = Workspace()

    private(set) var tabs: [WorkspaceTab] = []
    private(set) var selectedID: WorkspaceTab.ID?

    /// True while Command is held, which is when each tab shows the number that picks it.
    private(set) var showsTabNumbers = false

    /// How many tabs have a number: Command-1 to Command-9.
    static let numberedTabs = 9

    @ObservationIgnored private lazy var windowController = WorkspaceWindowController()

    /// Starts watching the Command key.
    ///
    /// Leaving the app also counts as letting go. Command-Tab switches away with the key
    /// still down, and its release then goes to the other app, never to this one.
    private init() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.setShowsTabNumbers(event.modifierFlags.contains(.command))
            return event
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setShowsTabNumbers(false)
            }
        }
    }

    private func setShowsTabNumbers(_ shows: Bool) {
        if showsTabNumbers != shows {
            showsTabNumbers = shows
        }
    }

    /// Adds a tab for a document that has just been opened, and shows it.
    func open(_ document: QuireDocument) {
        let hosting = NSHostingController(rootView: ContentView(document: document))
        hosting.sizingOptions = []

        let tab = WorkspaceTab(document: document, title: document.displayName, content: hosting)
        tabs.removeAll { $0.isStart }
        tabs.append(tab)
        select(tab)
    }

    /// Adds a tab showing the list of recent PDFs, and shows it.
    func openStart() {
        let hosting = NSHostingController(rootView: StartView())
        hosting.sizingOptions = []

        let tab = WorkspaceTab(document: nil, title: "Quire", content: hosting)
        tabs.append(tab)
        select(tab)
        showWindow()
    }

    func select(_ tab: WorkspaceTab) {
        selectedID = tab.id
        windowController.display(tab)
    }

    /// Shows the tab at a position in the strip, counting from zero.
    func selectTab(at index: Int) {
        if tabs.indices.contains(index) {
            select(tabs[index])
        }
    }

    /// Brings an open document's tab to the front, along with the window.
    func show(_ document: QuireDocument) {
        if let tab = tabs.first(where: { $0.document === document }) {
            select(tab)
        } else {
            open(document)
        }
        showWindow()
    }

    /// Brings the window back, with a start tab if nothing else is open.
    func reveal() {
        if tabs.isEmpty {
            openStart()
        } else {
            showWindow()
        }
    }

    /// Closes a tab, asking first if its PDF has unsaved changes.
    func close(_ tab: WorkspaceTab) {
        if let document = tab.document {
            windowController.close(document)
        } else {
            remove(tab)
        }
    }

    func closeSelected() {
        if let tab = tabs.first(where: { $0.id == selectedID }) {
            close(tab)
        }
    }

    /// Drops the tab of a document that is closing.
    func remove(_ document: QuireDocument) {
        if let tab = tabs.first(where: { $0.document === document }) {
            remove(tab)
        }
    }

    /// Drops every tab and closes the window, once nothing in it needs saving.
    func removeAll() {
        tabs.removeAll()
        selectedID = nil
        windowController.shutWindow()
    }

    /// Drops a tab, and shows the tab that took its place.
    ///
    /// The window closes with its last tab, and the app quits with its last window.
    private func remove(_ tab: WorkspaceTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let wasSelected = tab.id == selectedID
        tabs.remove(at: index)

        if tabs.isEmpty {
            removeAll()
        } else if wasSelected {
            select(tabs[min(index, tabs.count - 1)])
        }
    }

    /// Reads each document's name again, after a rename or a save under a new name.
    func refreshTitles() {
        for tab in tabs {
            if let document = tab.document, tab.title != document.displayName {
                tab.title = document.displayName
            }
        }
    }

    private func showWindow() {
        windowController.window?.makeKeyAndOrderFront(nil)
    }
}

/// The controller of Quire's one window.
///
/// AppKit expects each document to have a window controller of its own, and finds the
/// document to save, undo in or close by asking the front window's controller. This one
/// controller is therefore handed to whichever document's tab is showing, so the menus
/// always act on the PDF the user is looking at.
///
/// The title is hidden because the tab already carries it.
///
/// Closing is taken over as well. AppKit would close the showing document along with
/// the window and leave the rest open with nowhere to appear, so Cmd-W closes one tab,
/// and the window's close button closes every tab, asking about each unsaved PDF.
final class WorkspaceWindowController: NSWindowController, NSMenuItemValidation {
    /// The window saves and restores its size under this name.
    private static let frameName = NSWindow.FrameAutosaveName("QuireWindow")

    private static let defaultSize = NSSize(width: 1180, height: 820)

    private let container = WorkspaceViewController()

    /// Builds the window at the size last used.
    ///
    /// `setFrameAutosaveName` only registers where to save the frame. Restoring it is
    /// `setFrameUsingName`, and without that call the window opens at its coded size.
    convenience init() {
        self.init(window: nil)
        shouldCascadeWindows = false

        let window = NSWindow(contentViewController: container)
        window.title = "Quire"
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
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
    }

    /// Shows a tab, and hands this controller to its document.
    func display(_ tab: WorkspaceTab) {
        let current = document as? NSDocument

        if current !== tab.document {
            current?.removeWindowController(self)
            tab.document?.addWindowController(self)
        }
        if tab.isStart {
            document = nil
            window?.title = tab.title
        }
        container.show(tab.content)
    }

    /// Empties the window and closes it.
    func shutWindow() {
        (document as? NSDocument)?.removeWindowController(self)
        document = nil
        container.show(nil)

        if window?.isVisible == true {
            window?.close()
        }
    }

    /// Closes a document once it has been saved or the user has chosen not to.
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

    /// Shows the tab a menu item stands for, which it names by its tag.
    @objc func showTab(_ sender: Any?) {
        if let item = sender as? NSMenuItem {
            Workspace.shared.selectTab(at: item.tag)
        }
    }

    /// A tab's shortcut only works while there is a tab in that position.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showTab(_:)) {
            return menuItem.tag < Workspace.shared.tabs.count
        }
        return true
    }

    /// Closes every document in turn, stopping at the first one the user cancels on.
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

    /// AppKit calls this when the showing document's name changes, which is the moment
    /// its tab needs the new name too.
    override func synchronizeWindowTitleWithDocumentName() {
        super.synchronizeWindowTitleWithDocumentName()
        Workspace.shared.refreshTitles()
    }
}

/// The window's contents: the tab strip, and under it the tab that is showing.
///
/// Only the showing tab's view is in the window. The others are taken out rather than
/// hidden, because a hidden view still answers keyboard shortcuts, and Cmd-F would
/// then open Find in a tab the user cannot see.
final class WorkspaceViewController: NSViewController {
    private static let stripHeight = 38.0

    private let content = NSView()
    private var shown: NSViewController?

    override func loadView() {
        let strip = NSHostingView(rootView: TabStrip(workspace: .shared))
        strip.sizingOptions = []
        strip.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(strip)
        root.addSubview(content)

        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: root.topAnchor),
            strip.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: Self.stripHeight),

            content.topAnchor.constraint(equalTo: strip.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }

    /// Swaps the showing tab's view for another, or for nothing.
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
