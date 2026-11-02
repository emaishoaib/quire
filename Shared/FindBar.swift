import PDFKit
import SwiftUI

struct FindBar: View {
    static let animation = Animation.spring(duration: 0.28, bounce: 0.12)

    #if os(macOS)
    private static let width = 320.0
    private static let buttonSize = 20.0
    private static let iconSize = 12.0
    private static let rowPadding = 7.0
    #else
    private static let width = 420.0
    private static let buttonSize = 40.0
    private static let iconSize = 16.0
    private static let rowPadding = 12.0
    #endif

    let viewer: ViewerController
    let pdf: PDFDocument
    let focusRequests: Int
    @Binding var isPresented: Bool

    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field

            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                results
                    .transition(.scale(scale: 0.94, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(width: Self.width)
        .animation(Self.animation, value: query.isEmpty)
        .animation(Self.animation, value: viewer.matches.count)
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                isFocused = true
            }
        }
        .onChange(of: focusRequests) {
            isFocused = true
        }
        #if os(macOS)
        .onExitCommand(perform: close)
        #endif
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find in document", text: $query)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
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
                    #if os(iOS)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .contentShape(.rect)
                    #endif
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
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
                        ForEach(Array(viewer.matchGroups.enumerated()), id: \.element.text) { position, group in
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
                                .padding(.vertical, Self.rowPadding)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .transition(
                                .opacity
                                    .combined(with: .offset(y: -4))
                                    .animation(.easeOut(duration: 0.2).delay(Double(position) * 0.025))
                            )
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
                .font(.system(size: Self.iconSize, weight: .medium))
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func close() {
        viewer.clearSearch()
        query = ""
        withAnimation(Self.animation) {
            isPresented = false
        }
    }
}
