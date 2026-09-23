//
//  AppDelegate.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        OCRRunner.warmUp()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
