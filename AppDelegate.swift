import AppKit
import SwiftUI

@main
enum QuireMain {
    static let delegate = AppDelegate()

    static func main() {
        _ = QuireDocumentController()
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        OCRRunner.warmUp()
        ReadingPositions.removeOldList()

        if Workspace.shared.tabs.isEmpty {
            showStart(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            Workspace.shared.reveal()
        }
        return true
    }

    @objc func showStart(_ sender: Any?) {
        Workspace.shared.openStart()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        for case let document as QuireDocument in NSDocumentController.shared.documents {
            document.savePosition()
        }
    }
}

final class QuireDocumentController: NSDocumentController {
    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
    ) {
        let needsPlaceholder = displayDocument && document(for: url) == nil
        if needsPlaceholder {
            Workspace.shared.openPlaceholder(for: url)
        }
        super.openDocument(withContentsOf: url, display: displayDocument) { document, wasOpen, error in
            if needsPlaceholder && document == nil {
                Workspace.shared.removePlaceholder(for: url)
            }
            completionHandler(document, wasOpen, error)
        }
    }
}
