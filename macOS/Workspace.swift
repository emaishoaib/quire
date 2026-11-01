import AppKit
import SwiftUI

@MainActor
@Observable
final class WorkspaceTab: Identifiable {
    let id = UUID()
    let document: QuireDocument?
    let opening: URL?
    var title: String

    var isEdited = false

    @ObservationIgnored let content: NSViewController

    var isStart: Bool { document == nil && opening == nil }

    init(document: QuireDocument?, opening: URL? = nil, title: String, content: NSViewController) {
        self.document = document
        self.opening = opening
        self.title = title
        self.content = content
    }
}

@MainActor
@Observable
final class Workspace {
    static let shared = Workspace()

    private(set) var tabs: [WorkspaceTab] = []
    private(set) var selectedID: WorkspaceTab.ID?

    private(set) var showsTabNumbers = false

    private(set) var stripLeadingInset = 78.0

    static let numberedTabs = 9

    @ObservationIgnored private lazy var windowController = WorkspaceWindowController()

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

    func setStripLeadingInset(_ inset: Double) {
        if stripLeadingInset != inset {
            stripLeadingInset = inset
        }
    }

    private func setShowsTabNumbers(_ shows: Bool) {
        if showsTabNumbers != shows {
            showsTabNumbers = shows
        }
    }

    func open(_ document: QuireDocument) {
        let hosting = NSHostingController(rootView: ContentView(document: document))
        hosting.sizingOptions = []

        let tab = WorkspaceTab(document: document, title: document.displayName, content: hosting)
        tabs.removeAll { $0.isStart }
        if let index = placeholderIndex(for: document.fileURL) {
            tabs[index] = tab
        } else {
            tabs.append(tab)
        }
        select(tab)
    }

    func openPlaceholder(for url: URL) {
        let hosting = NSHostingController(rootView: OpeningView(url: url))
        hosting.sizingOptions = []

        let title = FileManager.default.displayName(atPath: url.path)
        let tab = WorkspaceTab(document: nil, opening: url, title: title, content: hosting)
        tabs.removeAll { $0.isStart }
        tabs.append(tab)
        select(tab)
        showWindow()
    }

    func removePlaceholder(for url: URL) {
        guard let index = placeholderIndex(for: url) else { return }
        let tab = tabs[index]
        if tabs.count == 1 {
            openStart()
        }
        remove(tab)
    }

    private func placeholderIndex(for url: URL?) -> Int? {
        guard let url else { return nil }
        return tabs.firstIndex { $0.opening?.standardizedFileURL == url.standardizedFileURL }
    }

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
        refreshTabs()
    }

    func move(_ tab: WorkspaceTab, to index: Int) {
        guard let current = tabs.firstIndex(where: { $0.id == tab.id }),
              current != index, tabs.indices.contains(index)
        else { return }
        tabs.insert(tabs.remove(at: current), at: index)
    }

    func selectTab(at index: Int) {
        if tabs.indices.contains(index) {
            select(tabs[index])
        }
    }

    func show(_ document: QuireDocument) {
        if let tab = tabs.first(where: { $0.document === document }) {
            select(tab)
        } else {
            open(document)
        }
        showWindow()
    }

    func reveal() {
        if tabs.isEmpty {
            openStart()
        } else {
            showWindow()
        }
    }

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

    func remove(_ document: QuireDocument) {
        if let tab = tabs.first(where: { $0.document === document }) {
            remove(tab)
        }
    }

    func removeAll() {
        tabs.removeAll()
        selectedID = nil
        windowController.shutWindow()
    }

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

    func refreshTabs() {
        for tab in tabs {
            guard let document = tab.document else { continue }
            if tab.title != document.displayName {
                tab.title = document.displayName
            }
            if tab.isEdited != document.isDocumentEdited {
                tab.isEdited = document.isDocumentEdited
            }
        }
    }

    private func showWindow() {
        windowController.window?.makeKeyAndOrderFront(nil)
    }
}
