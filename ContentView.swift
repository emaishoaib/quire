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
    @State private var confirmsMerge = false
    @State private var mergeSummary: String?
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                HStack(spacing: 0) {
                    if mode == .read && showsThumbnails {
                        VStack(spacing: 0) {
                            ThumbnailSidebar(
                                document: document,
                                viewer: viewer,
                                thumbnailWidth: thumbnailWidth
                            )

                            Divider()

                            ThumbnailSizeControl(thumbnailWidth: $thumbnailWidth)
                        }
                        .frame(width: ThumbnailSidebar.sidebarWidth(for: thumbnailWidth))
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .animation(ThumbnailSidebar.sizeAnimation, value: thumbnailWidth)
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
                        renameUnavailableReason: renameUnavailableReason,
                        showsRename: $showsRename,
                        canMerge: !mergeCandidates.isEmpty,
                        confirmsMerge: $confirmsMerge,
                        showsFind: $showsFind,
                        mode: $mode,
                        showsThumbnails: $showsThumbnails
                    )
                }
                .animation(ThumbnailSidebar.animation, value: showsThumbnails)
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
        .onChange(of: showsRename) { _, isShown in
            if !isShown {
                refreshFolder()
            }
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
        .task {
            refreshFolder()
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                refreshFolder()
            }
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

    /// Looks at the folder again, for similarly named PDFs and for a naming pattern.
    ///
    /// Files can appear in the folder while Quire is in the background, so this runs
    /// whenever the app comes back to the front, as well as when the window opens and
    /// after a merge or rename has changed the folder.
    private func refreshFolder() {
        mergeCandidates = document.similarlyNamedFiles()
        namePattern = document.namePattern()
    }

    /// Why the rename button is disabled, or nil when it is not.
    private var renameUnavailableReason: String? {
        if namePattern == nil {
            return "The other PDFs in this folder don't share a naming pattern to rename to"
        }
        return NameExtractor.unavailableReason
    }

    private var mergeConfirmation: String {
        let names = mergeCandidates.map(\.lastPathComponent).joined(separator: "\n")
        return "The pages of these files will be added to the end of this PDF:\n\n\(names)\n\n"
            + "This PDF will then be saved, and the files moved to the Trash."
    }

    /// Merges the files listed in the confirmation, and reports how it went.
    ///
    /// The list is emptied first, which disables the button, so a second click cannot
    /// start a second merge of the same files while the first is saving.
    private func merge() {
        let files = mergeCandidates
        let pagesBefore = document.pageCount
        mergeCandidates = []

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
            refreshFolder()
        }
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
