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
@main
enum QuireMain {
    static let delegate = AppDelegate()

    static func main() {
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

    private var startWindows: [NSWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        OCRRunner.warmUp()

        if NSDocumentController.shared.documents.isEmpty {
            showStart(nil)
        }
    }

    /// Opening the app with no file shows the start screen rather than an empty document.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showStart(nil)
        }
        return true
    }

    /// The plus button at the end of the tab bar, which AppKit shows because this exists.
    @objc func newWindowForTab(_ sender: Any?) {
        showStart(sender)
    }

    /// Opens a tab showing the list of recent PDFs.
    @objc func showStart(_ sender: Any?) {
        let hosting = NSHostingController(rootView: StartView())
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.title = "Quire"
        window.setContentSize(NSSize(width: 900, height: 700))

        let controller = NSWindowController(window: window)
        startWindows.append(controller)
        WindowTabs.show(window)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startWindows.removeAll { $0.window === window }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
