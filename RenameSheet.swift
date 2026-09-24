//
//  RenameSheet.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import PDFKit
import SwiftUI

/// The sheet that renames a PDF to follow the naming pattern of the files beside it.
///
/// The on-device model reads the document as soon as the sheet opens, and its suggestion
/// lands in an editable field, because it can misread a date or pick the wrong words. If
/// the model fails, the field shows the pattern itself, placeholders and all, so the name
/// can still be typed by hand. Renaming stays disabled while any placeholder is left.
struct RenameSheet: View {
    let document: QuireDocument
    let pattern: NamePattern

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isReading = true
    @State private var isRenaming = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename to Match This Folder")
                .font(.headline)

            LabeledContent("Pattern") {
                Text(pattern.description)
                    .textSelection(.enabled)
            }
            .font(.callout)

            if isReading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading the document…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 22)
            } else {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(rename)
            }

            if let failure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: rename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRename)
            }
        }
        .padding(20)
        .frame(width: 460)
        .task { await suggest() }
    }

    private var canRename: Bool {
        !isReading && !isRenaming && !hasPlaceholder && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasPlaceholder: Bool {
        ["<date>", "<amount>", "<text>"].contains { name.contains($0) }
    }

    private func suggest() async {
        do {
            name = try await NameExtractor.suggestName(following: pattern, for: document.pdf.string ?? "")
        } catch {
            name = pattern.description
            failure = error.localizedDescription
        }
        isReading = false
    }

    private func rename() {
        guard canRename else { return }
        isRenaming = true
        failure = nil
        Task {
            do {
                try await document.rename(to: name)
                dismiss()
            } catch {
                failure = error.localizedDescription
            }
            isRenaming = false
        }
    }
}
