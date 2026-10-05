//
//  MainMenu.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit

/// Builds the menu bar.
///
/// The items use AppKit's standard selectors, so the document system answers them:
/// `NSDocumentController` handles New, Open and Open Recent, the open document handles
/// Save, Save As and Revert, and its undo manager handles Undo and Redo. Close Tab goes
/// to the window's controller, because a tab is Quire's own and AppKit knows nothing of it.
enum MainMenu {

    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu: appMenu(), title: "Quire")
        menu.addItem(submenu: fileMenu(), title: "File")
        menu.addItem(submenu: editMenu(), title: "Edit")
        menu.addItem(submenu: windowMenu(), title: "Window")
        return menu
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Quire")
        menu.addItem(withTitle: "About Quire", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Quire", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        let hideOthers = menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quire", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "New Tab", action: Selector(("showStart:")), keyEquivalent: "n")
        menu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")

        let recent = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        recent.submenu = NSMenu(title: "Open Recent")
        recent.submenu?.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        menu.addItem(recent)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Close Tab", action: #selector(WorkspaceWindowController.closeTab(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")

        let saveAs = menu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        menu.addItem(withTitle: "Export Copy…", action: Selector(("exportCopy:")), keyEquivalent: "e")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Print…", action: #selector(NSDocument.printDocument(_:)), keyEquivalent: "p")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")

        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        addTabItems(to: menu)
        NSApp.windowsMenu = menu
        return menu
    }
}

private extension MainMenu {
    /// Adds the items behind Command-1 to Command-9, which show the tab in that position.
    ///
    /// They are hidden from the menu but still answer their keys. The tabs already show
    /// their own numbers while Command is held, so a list of them here would add nothing.
    static func addTabItems(to menu: NSMenu) {
        for index in 0..<Workspace.numberedTabs {
            let item = menu.addItem(
                withTitle: "Show Tab \(index + 1)",
                action: #selector(WorkspaceWindowController.showTab(_:)),
                keyEquivalent: "\(index + 1)"
            )
            item.tag = index
            item.isHidden = true
            item.allowsKeyEquivalentWhenHidden = true
        }
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
