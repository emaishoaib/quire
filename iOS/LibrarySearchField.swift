import SwiftUI

struct LibrarySearchField: View {
    private static var height: Double { 48 }

    @Binding var text: String

    @FocusState private var isFocused: Bool

    private var isActive: Bool { isFocused || !text.isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            field

            if isActive {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .frame(width: Self.height, height: Self.height)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close Search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .foregroundStyle(Color.cream)
        .animation(.snappy, value: isActive)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .opacity(0.6)

            TextField("Search", text: $text, prompt: Text("Search your library").foregroundStyle(Color.cream.opacity(0.5)))
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Self.height)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func close() {
        text = ""
        isFocused = false
    }
}
