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

    var fileURL: URL? { document?.fileURL ?? opening }

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

    @ObservationIgnored private var isHoldingSavedTabs = false
    @ObservationIgnored private var isClosingFromTab = false

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
        guard let index = placeholderIndex(for: document.fileURL) else {
            tabs.append(tab)
            select(tab)
            return
        }
        let wasSelected = tabs[index].id == selectedID
        tabs[index] = tab
        if wasSelected {
            select(tab)
        } else {
            saveOpenTabs()
        }
    }

    func openPlaceholder(for url: URL) {
        if let index = placeholderIndex(for: url) {
            select(tabs[index])
        } else {
            tabs.removeAll { $0.isStart }
            let tab = placeholder(for: url)
            tabs.append(tab)
            select(tab)
        }
        showWindow()
    }

    private func placeholder(for url: URL) -> WorkspaceTab {
        let hosting = NSHostingController(rootView: OpeningView(url: url))
        hosting.sizingOptions = []

        let title = FileManager.default.displayName(atPath: url.path)
        return WorkspaceTab(document: nil, opening: url, title: title, content: hosting)
    }

    /// Opens the files that were open when Quire last ran, in front of any tab opened since launch.
    func reopenSavedTabs() {
        let files = OpenTabs.files.filter { url in
            placeholderIndex(for: url) == nil && NSDocumentController.shared.document(for: url) == nil
        }
        guard !files.isEmpty else { return }

        let savedSelection = OpenTabs.selected
        tabs.removeAll { $0.isStart }
        tabs.insert(contentsOf: files.map(placeholder(for:)), at: 0)

        if selectedID == nil || !tabs.contains(where: { $0.id == selectedID }) {
            select(tabs[placeholderIndex(for: savedSelection) ?? 0])
        } else {
            saveOpenTabs()
        }
        showWindow()

        for url in files {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: false) { document, _, _ in
                if let document = document as? QuireDocument {
                    document.makeWindowControllers()
                } else {
                    Workspace.shared.removePlaceholder(for: url)
                }
            }
        }
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
        saveOpenTabs()
    }

    func move(_ tab: WorkspaceTab, to index: Int) {
        guard let current = tabs.firstIndex(where: { $0.id == tab.id }),
              current != index, tabs.indices.contains(index)
        else { return }
        tabs.insert(tabs.remove(at: current), at: index)
        saveOpenTabs()
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

    /// Closes a document the person closed from its tab, the one kind of document close that drops it from the saved tabs.
    func closeFromTab(_ document: NSDocument) {
        isClosingFromTab = true
        document.close()
        isClosingFromTab = false
    }

    /// Drops a closed document's tab, keeping it in the saved tabs unless it was closed from its tab, as when quitting closes it.
    func remove(_ document: QuireDocument) {
        guard let tab = tabs.first(where: { $0.document === document }) else { return }
        isHoldingSavedTabs = !isClosingFromTab
        remove(tab)
        isHoldingSavedTabs = false
    }

    func removeAll() {
        tabs.removeAll()
        selectedID = nil
        windowController.shutWindow()
        saveOpenTabs()
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
        saveOpenTabs()
    }

    private func saveOpenTabs() {
        guard !isHoldingSavedTabs else { return }
        let selected = tabs.first { $0.id == selectedID }?.fileURL
        OpenTabs.save(tabs.compactMap(\.fileURL), selected: selected)
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
