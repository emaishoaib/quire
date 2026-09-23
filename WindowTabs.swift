//
//  WindowTabs.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit
import SwiftUI

extension NSWindow {
    /// True for a window showing the start screen rather than a document.
    var isStartTab: Bool {
        windowController?.document == nil && contentViewController is NSHostingController<StartView>
    }
}

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
    static let identifier = NSWindow.TabbingIdentifier("com.mashoaib.quire.tabs")

    /// Every window saves and restores its size under this one name, so a document window
    /// and a start screen are always the size the user last left, and a tab joining the
    /// group does not resize it.
    private static let frameName = NSWindow.FrameAutosaveName("QuireWindow")

    private static let defaultSize = NSSize(width: 1180, height: 820)

    /// Prepares a window to live in the tab group, at the size last used.
    ///
    /// The title is hidden because the tab already carries it: left visible, the file name
    /// appears twice, once in the title bar and once on the tab beneath it.
    ///
    /// `setFrameAutosaveName` only registers where to save the frame. Restoring it is
    /// `setFrameUsingName`, and without that call every window opens at its coded size.
    static func prepare(_ window: NSWindow) {
        window.tabbingIdentifier = identifier
        window.tabbingMode = .preferred
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 720, height: 520)

        window.setContentSize(defaultSize)
        window.setFrameAutosaveName(frameName)

        if !window.setFrameUsingName(frameName) {
            window.center()
        }
    }

    /// Shows a window as a tab of the existing group, or on its own if there is none.
    ///
    /// Any start tab in that group is closed: the start screen exists to open something,
    /// so once something is open it has done its job, however the file was opened.
    static func show(_ window: NSWindow, replacingStartTabs: Bool = false) {
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
            window.makeKeyAndOrderFront(nil)
        }

        if replacingStartTabs {
            closeStartTabs(besides: window)
        }
        showTabBar(in: window)
    }

    /// Closes every start tab in the window's tab group.
    private static func closeStartTabs(besides window: NSWindow) {
        let tabs = window.tabGroup?.windows ?? []
        for tab in tabs where tab !== window && tab.isStartTab {
            tab.close()
        }
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
