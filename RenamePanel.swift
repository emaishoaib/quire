//
//  RenamePanel.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import PDFKit
import SwiftUI

/// The panel that renames a PDF to follow the naming pattern of the files beside it.
///
/// It floats over the top-right corner of the document rather than being a sheet, so the
/// document stays usable underneath, and the suggestion can be checked against the pages
/// by scrolling to them while the panel is open.
///
/// The document is read as soon as the panel opens, and the suggestion lands in an
/// editable field, because it can pick the wrong date, amount or words. Whatever could not
/// be read keeps its placeholder, and a document with no text gets the pattern itself, so
/// the name can still be typed by hand. Renaming stays disabled while any placeholder is left.
///
/// Return in the field renames. The button has no Return shortcut of its own, because
/// with no sheet around it, that shortcut would also catch Return pressed in the Find panel.
struct RenamePanel: View {
    let document: QuireDocument
    let pattern: NamePattern
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var isRenaming = false
    @State private var failure: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rename to Match This Folder")
                    .font(.headline)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            LabeledContent("Pattern") {
                Text(pattern.description)
                    .textSelection(.enabled)
            }
            .font(.callout)

            if !namesBefore.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before this one")
                    ForEach(namesBefore, id: \.self) { example in
                        Text(example)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(rename)

            if let failure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Rename", action: rename)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRename)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        .task { await suggest() }
        .onExitCommand(perform: close)
    }

    /// The three names following the pattern that would sit just above this one in Finder.
    ///
    /// They are worked out against the name in the field, so editing its date moves the
    /// list with it. Until there is a name, the last three are shown.
    private var namesBefore: [String] {
        let sorted = pattern.examples.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let current = name.trimmingCharacters(in: .whitespaces)
        guard !current.isEmpty else {
            return Array(sorted.suffix(3))
        }
        return Array(sorted.prefix(while: { $0.localizedStandardCompare(current) == .orderedAscending }).suffix(3))
    }

    private var canRename: Bool {
        !isRenaming && !hasPlaceholder && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasPlaceholder: Bool {
        ["<date>", "<period>", "<amount>", "<text>"].contains { name.contains($0) }
    }

    /// Fills the field with the suggestion, then puts the cursor in it.
    ///
    /// Focus waits a moment, as in the Find panel, because the panel has only just been
    /// added and focus asked for straight away is lost.
    private func suggest() async {
        do {
            name = try NameReader.suggestName(following: pattern, for: document.pdf.string ?? "")
        } catch {
            name = pattern.description
            failure = error.localizedDescription
        }
        try? await Task.sleep(for: .milliseconds(60))
        isFocused = true
    }

    private func rename() {
        guard canRename else { return }
        isRenaming = true
        failure = nil
        Task {
            do {
                try await document.rename(to: name)
                close()
            } catch {
                failure = error.localizedDescription
            }
            isRenaming = false
        }
    }

    private func close() {
        withAnimation(FindBar.animation) {
            isPresented = false
        }
    }
}
