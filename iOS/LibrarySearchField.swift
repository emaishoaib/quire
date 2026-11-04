import SwiftUI

struct LibrarySearchField: View {
    @Binding var text: String
    let close: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .opacity(0.6)

            TextField("Search", text: $text, prompt: Text("Search this folder").foregroundStyle(Color.cream.opacity(0.5)))
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            Button("Close Search", systemImage: "xmark.circle.fill", action: close)
                .labelStyle(.iconOnly)
                .opacity(0.6)
        }
        .font(.body)
        .foregroundStyle(Color.cream)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cream.opacity(0.12), in: .capsule)
        .onAppear { isFocused = true }
    }
}
