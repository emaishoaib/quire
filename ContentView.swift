//
//  ContentView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// Which half of the app the window is showing.
enum Mode: String, CaseIterable, Identifiable {
    case read = "Read"
    case pages = "Pages"

    var id: Self { self }

    /// How the window changes between reading and organising.
    ///
    /// Applied wherever the mode is set rather than in the views, because a view being
    /// swapped for another cannot animate its own arrival.
    static let animation = Animation.spring(duration: 0.32, bounce: 0.1)
}

/// The window's contents: the open PDF, or an empty state for a document with no pages.
struct ContentView: View {
    @Bindable var document: QuireDocument

    @State private var viewer = ViewerController()
    @State private var ocr = OCRRunner()
    @State private var showsFind = false
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @State private var namePattern: NamePattern?
    @State private var showsRename = false
    @State private var mergeCandidates: [URL] = []
    @State private var unreadableFolder: URL?
    @State private var explainsFolderAccess = false
    @State private var confirmsMerge = false
    @State private var mergeSummary: String?
    @State private var isMerging = false
    @State private var folderNotice: FolderNotice?
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0
    @AppStorage("sidebarTab") private var sidebarTab = SidebarTab.thumbnails

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                HStack(spacing: 0) {
                    if mode == .read && showsThumbnails {
                        sidebar
                            .transition(.move(edge: .leading).combined(with: .opacity))

                        Divider()
                            .transition(.opacity)
                    }

                    Group {
                        switch mode {
                        case .read:
                            PDFViewer(pdf: document.pdf, revision: document.revision, controller: viewer)
                                .overlay(alignment: .trailing) {
                                    ZoomHUD(viewer: viewer)
                                        .padding(.trailing, 16)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        case .pages:
                            PageGrid(document: document, selection: $selection) { index in
                                withAnimation(Mode.animation) {
                                    mode = .read
                                }
                                viewer.goToPage(index)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        panels
                    }

                    Divider()

                    ReadRail(
                        viewer: viewer,
                        ocr: ocr,
                        document: document,
                        rename: startRename,
                        merge: startMerge,
                        isMerging: isMerging,
                        showsFind: $showsFind,
                        mode: $mode,
                        showsThumbnails: $showsThumbnails,
                        sidebarTab: $sidebarTab
                    )
                }
                .animation(ThumbnailSidebar.animation, value: showsThumbnails)
                .animation(ThumbnailSidebar.animation, value: sidebarTab)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background {
            Button("Find") {
                withAnimation(Mode.animation) {
                    mode = .read
                }
                withAnimation(FindBar.animation) {
                    showsFind = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        }
        .onChange(of: viewer.matches.isEmpty) { _, isEmpty in
            if !isEmpty {
                withAnimation(FindBar.animation) {
                    showsFind = true
                }
            }
        }
        .onChange(of: document.revision) {
            viewer.clearSearch()
            selection = selection.filter { $0 < document.pageCount }
        }
        .sheet(isPresented: $ocr.isRunning) {
            OCRProgressView(ocr: ocr)
        }
        .alert("Recognize Text", isPresented: showingSummary) {
            Button("OK") {}
        } message: {
            Text(ocr.summary ?? "")
        }
        .alert("Merge Similarly Named PDFs", isPresented: $confirmsMerge) {
            Button("Merge and Move to Trash", role: .destructive) { merge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(mergeConfirmation)
        }
        .alert("Merge Similarly Named PDFs", isPresented: showingMergeSummary) {
            Button("OK") {}
        } message: {
            Text(mergeSummary ?? "")
        }
        .alert("Quire Can't Read This Folder", isPresented: $explainsFolderAccess) {
            Button("Open Privacy Settings", action: openFilesAndFolders)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(folderAccessMessage)
        }
        .alert(folderNotice?.title ?? "", isPresented: showingFolderNotice) {
            Button("OK") {}
        } message: {
            Text(folderNotice?.message ?? "")
        }
    }

    /// The sidebar beside the document in Read mode, showing thumbnails or contents.
    ///
    /// The rail switches between the two. The tab is `@AppStorage`, so the switch is
    /// animated from the container holding both the sidebar and the rail, keyed to the
    /// tab, for the same reason as the sidebar's toggle.
    private var sidebar: some View {
        VStack(spacing: 0) {
            switch sidebarTab {
            case .thumbnails:
                ThumbnailSidebar(
                    document: document,
                    viewer: viewer,
                    thumbnailWidth: thumbnailWidth
                )

                Divider()

                ThumbnailSizeControl(thumbnailWidth: $thumbnailWidth)
            case .contents:
                ContentsSidebar(document: document)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: sidebarWidth)
        .background(Color(nsColor: .underPageBackgroundColor))
        .animation(ThumbnailSidebar.sizeAnimation, value: thumbnailWidth)
    }

    private var sidebarWidth: Double {
        switch sidebarTab {
        case .thumbnails: ThumbnailSidebar.sidebarWidth(for: thumbnailWidth)
        case .contents: ContentsSidebar.width
        }
    }

    /// The Find and rename panels, stacked in the top-right corner of the document.
    ///
    /// They share one corner so that with both open, the rename panel sits below Find
    /// rather than on top of it. Find belongs to reading, while renaming works from
    /// Pages too.
    private var panels: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if mode == .read && showsFind {
                FindBar(viewer: viewer, pdf: document.pdf, isPresented: $showsFind)
                    .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
            }
            if showsRename, let namePattern {
                RenamePanel(document: document, pattern: namePattern, isPresented: $showsRename)
                    .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .padding(16)
    }

    private var showingSummary: Binding<Bool> {
        Binding(
            get: { ocr.summary != nil },
            set: { if !$0 { ocr.summary = nil } }
        )
    }

    private var showingMergeSummary: Binding<Bool> {
        Binding(
            get: { mergeSummary != nil },
            set: { if !$0 { mergeSummary = nil } }
        )
    }

    /// What rename or merge found when the folder had nothing for it.
    private struct FolderNotice {
        let title: String
        let message: String
    }

    private var showingFolderNotice: Binding<Bool> {
        Binding(
            get: { folderNotice != nil },
            set: { if !$0 { folderNotice = nil } }
        )
    }

    /// Reads the folder for a naming pattern, and opens the rename panel if there is one.
    ///
    /// The folder is read on the click rather than when the window opens, because reading
    /// a folder such as Documents or Downloads is what makes macOS ask whether Quire may.
    /// Reading it at launch asked that question of everyone who opened a PDF, before
    /// they had used anything that needs the answer.
    private func startRename() {
        do {
            namePattern = try document.namePattern()
        } catch {
            explainUnreadableFolder()
            return
        }
        guard namePattern != nil else {
            folderNotice = FolderNotice(
                title: "Rename to Match This Folder",
                message: "The other PDFs in this folder don't share a naming pattern to rename to."
            )
            return
        }
        withAnimation(FindBar.animation) {
            showsRename = true
        }
    }

    /// Reads the folder for similarly named PDFs, and asks to merge them if there are any.
    ///
    /// The folder is read on the click for the same reason as in `startRename`.
    private func startMerge() {
        do {
            mergeCandidates = try document.similarlyNamedFiles()
        } catch {
            explainUnreadableFolder()
            return
        }
        guard !mergeCandidates.isEmpty else {
            let name = document.fileURL?.deletingPathExtension().lastPathComponent ?? "this PDF"
            folderNotice = FolderNotice(
                title: "Merge Similarly Named PDFs",
                message: "There are no PDFs in this folder named \u{201C}\(name)\u{201D} with something added, "
                    + "such as \u{201C}\(name) 2\u{201D}."
            )
            return
        }
        confirmsMerge = true
    }

    private func explainUnreadableFolder() {
        unreadableFolder = document.fileURL?.deletingLastPathComponent()
        explainsFolderAccess = true
    }

    private var folderAccessMessage: String {
        let name = unreadableFolder.map { FileManager.default.displayName(atPath: $0.path) } ?? "this folder"
        return "macOS isn't letting Quire look inside \u{201C}\(name)\u{201D}, so it can't find the other PDFs "
            + "there to rename to or merge.\n\nAllow Quire under Files and Folders in Privacy & Security, "
            + "then click the button again."
    }

    /// Opens the Files and Folders page of Privacy & Security in System Settings.
    ///
    /// The folder is read again on the next click, so access granted there takes effect
    /// without a restart.
    private func openFilesAndFolders() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
            NSWorkspace.shared.open(url)
        }
    }

    private var mergeConfirmation: String {
        let names = mergeCandidates.map(\.lastPathComponent).joined(separator: "\n")
        return "The pages of these files will be added to the end of this PDF:\n\n\(names)\n\n"
            + "This PDF will then be saved, and the files moved to the Trash."
    }

    /// Merges the files listed in the confirmation, and reports how it went.
    ///
    /// The button is disabled until it finishes, because the files stay in the folder
    /// until the save succeeds, and a second click would offer to merge them again.
    private func merge() {
        let files = mergeCandidates
        let pagesBefore = document.pageCount
        mergeCandidates = []
        isMerging = true

        Task {
            do {
                let untrashed = try await document.mergeAndTrash(files)
                let added = document.pageCount - pagesBefore
                var message = "Added \(added) page\(added == 1 ? "" : "s") from \(files.count) "
                    + "file\(files.count == 1 ? "" : "s") and saved this PDF."
                if untrashed.isEmpty {
                    message += " The files were moved to the Trash."
                } else {
                    let names = untrashed.map(\.lastPathComponent).joined(separator: "\n")
                    message += " These could not be moved to the Trash:\n\n\(names)"
                }
                mergeSummary = message
            } catch {
                mergeSummary = "The files were left where they are. \(error.localizedDescription)"
            }
            isMerging = false
        }
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
