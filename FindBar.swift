//
//  FindBar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// The find panel, opened with Cmd-F and closed with Escape or its close button.
///
/// Results appear as you type, listed underneath by what they matched and how often,
/// rather than only as a count. Clicking a row jumps to the first of that form, and the
/// arrows beside the count step through them one at a time.
///
/// The field takes focus a moment after the panel appears, rather than immediately: the
/// panel is not yet in the window when `onAppear` runs, and focus asked for then is lost.
struct FindBar: View {
    let viewer: ViewerController
    let pdf: PDFDocument
    @Binding var isPresented: Bool

    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field

            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                results
            }
        }
        .frame(width: 320)
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                isFocused = true
            }
        }
        .onExitCommand(perform: close)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find in document", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { viewer.submitSearch(query, in: pdf) }
                .onChange(of: query) { _, text in
                    viewer.search(text, in: pdf)
                }

            if !viewer.matches.isEmpty {
                Text("\(viewer.matchIndex + 1)/\(viewer.matches.count)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .contentTransition(.numericText())

                iconButton("Previous Match", systemImage: "chevron.up") { viewer.previousMatch() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])

                iconButton("Next Match", systemImage: "chevron.down") { viewer.nextMatch() }
                    .keyboardShortcut("g", modifiers: .command)
            }

            Menu {
                Toggle("Match Case", isOn: Binding(
                    get: { viewer.matchCase },
                    set: { newValue in
                        viewer.matchCase = newValue
                        viewer.search(query, in: pdf)
                    }
                ))
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Search options")

            Divider()
                .frame(height: 16)

            iconButton("Close", systemImage: "xmark", action: close)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EXACT MATCHES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewer.matches.count)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if viewer.matches.isEmpty {
                Text("No results")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewer.matchGroups, id: \.text) { group in
                            Button {
                                viewer.goToMatch(group.firstIndex)
                            } label: {
                                HStack {
                                    Text(group.text)
                                        .font(.system(size: 13))
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(group.count)")
                                        .font(.system(size: 11))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    private func iconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func close() {
        viewer.clearSearch()
        query = ""
        isPresented = false
    }
}
