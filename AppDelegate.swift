//
//  AppDelegate.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit
import SwiftUI

/// The entry point.
///
/// `@main` on the delegate class itself is not enough in an AppKit app: that spelling
/// expects a MainMenu nib to create the delegate object, and this app has no nibs, so
/// the delegate is never made and the menu bar never appears. The app is therefore
/// started by hand, with the delegate held here because `NSApplication` keeps only a
/// weak reference to it.
///
/// The document controller is made first. AppKit keeps the first one made as the
/// shared one, so it has to exist before anything asks for `NSDocumentController.shared`.
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

/// The application itself.
///
/// Quire is an AppKit document app rather than a SwiftUI one, so the menu bar that
/// `DocumentGroup` used to provide is built here. Closing the last window quits, which
/// is safe because an unsaved document is asked about before its window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Builds the menu bar, and shows the start screen unless Quire opened to read a PDF.
    ///
    /// The tabs are checked rather than the open documents. A PDF opened from Finder is
    /// often still being read at this point, so it is not yet a document, but it already
    /// has a tab standing in for it.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        OCRRunner.warmUp()
        ReadingPositions.removeOldList()

        if Workspace.shared.tabs.isEmpty {
            showStart(nil)
        }
    }

    /// Opening the app with no file shows the start screen rather than an empty document.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            Workspace.shared.reveal()
        }
        return true
    }

    /// Opens a tab showing the list of recent PDFs.
    @objc func showStart(_ sender: Any?) {
        Workspace.shared.openStart()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Remembers where every open PDF is scrolled to.
    ///
    /// AppKit does close each document while quitting, but only as the last thing it
    /// does on its way out. The positions are saved here first, rather than rely on that.
    func applicationWillTerminate(_ notification: Notification) {
        for case let document as QuireDocument in NSDocumentController.shared.documents {
            document.savePosition()
        }
    }
}

/// Opens every PDF, wherever the request to open it comes from.
///
/// Finder, File → Open Recent, the Open panel and the start screen all open files
/// through `openDocument(withContentsOf:display:completionHandler:)`, so this is the one
/// place that sees every PDF on its way in. A tab stands in for the PDF from that moment,
/// so it is clear the file arrived even while it takes a while to read.
///
/// A PDF that is already open needs no stand-in, because its tab is simply brought to
/// the front. A PDF that fails to open loses its stand-in before the error is shown.
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
