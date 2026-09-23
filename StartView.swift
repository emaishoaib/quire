//
//  StartView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The screen shown when Quire opens with nothing to read.
///
/// The list is AppKit's own record of recently opened documents, the same one behind
/// File → Open Recent, and files open through the document controller so that they are
/// opened exactly as that menu would open them.
///
/// Everything sits in a column of its own rather than filling the window, because a tab
/// is as wide as the window and a full-width list of a few files reads as broken.
struct StartView: View {
    @State private var recents = NSDocumentController.shared.recentDocumentURLs
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                Divider()

                if recents.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: hasAppeared)
            .frame(maxWidth: 680)
            .padding(.top, 56)
            .padding(.bottom, 40)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            recents = NSDocumentController.shared.recentDocumentURLs
            hasAppeared = true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quire")
                    .font(.system(size: 20, weight: .semibold))

                Text("Read, organise and recognise text in PDFs")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open…", action: openPanel)
                .controlSize(.large)
        }
        .padding(20)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No Recent PDFs", systemImage: "clock")
        } description: {
            Text("PDFs you open will be listed here.")
        } actions: {
            Button("Open…", action: openPanel)
        }
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(recents.enumerated()), id: \.element) { index, url in
                Button {
                    open(url)
                } label: {
                    row(for: url)
                }
                .buttonStyle(.plain)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 6)
                .animation(
                    .easeOut(duration: 0.25).delay(0.08 + Double(index) * 0.035),
                    value: hasAppeared
                )

                if index < recents.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    private func row(for url: URL) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Text(url.deletingLastPathComponent().path.replacingOccurrences(
                    of: NSHomeDirectory(),
                    with: "~"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .contentShape(.rect)
    }

    /// Opens a file chosen by the user. The document closes this tab as it opens.
    private func openPanel() {
        NSDocumentController.shared.openDocument(nil)
    }

    /// Opens a recent file. The document closes this tab as it opens.
    private func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
}
