//
//  WindowTabs.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit

/// Keeps every Quire window in one tabbed window.
///
/// macOS only merges windows into tabs by itself when the user has asked for it in
/// System Settings, so each new window is added to the existing tab group explicitly.
/// A tab holding no PDF shows the start screen, and opening a file from there closes
/// that tab, so the tab is replaced rather than joined by a second one.
///
/// A new tab takes the frame of the window it joins, because a tab group resizes itself
/// to whatever window is added, which would otherwise resize the window under the user.
enum WindowTabs {
    static let identifier = NSWindow.TabbingIdentifier("com.mashoaib.Quire.tabs")

    /// Prepares a window to live in the tab group.
    ///
    /// The title is hidden because the tab already carries it: left visible, the file name
    /// appears twice, once in the title bar and once on the tab beneath it.
    static func prepare(_ window: NSWindow) {
        window.tabbingIdentifier = identifier
        window.tabbingMode = .preferred
        window.titleVisibility = .hidden
    }

    /// Shows a window as a tab of the existing group, or on its own if there is none.
    static func show(_ window: NSWindow) {
        prepare(window)

        if let host = NSApp.windows.first(where: { other in
            other !== window
                && other.tabbingIdentifier == identifier
                && other.isVisible
        }) {
            window.setFrame(host.frame, display: false)
            host.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        showTabBar(in: window)
    }

    /// Keeps the tab bar on screen even with a single tab.
    ///
    /// macOS hides it below two tabs, which also hides the plus button, so a lone tab
    /// would leave no way to open another one.
    private static func showTabBar(in window: NSWindow) {
        DispatchQueue.main.async {
            if window.tabGroup?.isTabBarVisible == false {
                window.toggleTabBar(nil)
            }
        }
    }
}
