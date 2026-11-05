import SwiftUI

struct PageIndicator: View {
    #if os(macOS)
    private static let fieldHeight = 24.0
    #else
    private static let fieldHeight = 36.0
    #endif

    let viewer: ViewerController
    let pageCount: Int
    var isInline = false
    var editingChanged: (Bool) -> Void = { _ in }

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        let layout = isInline ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 6))

        layout {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .frame(width: fieldWidth, height: Self.fieldHeight)
                .background(.background.secondary, in: .rect(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator))
                .focused($isFocused)
                .onSubmit(jump)

            Text("\(pageCount)")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .monospacedDigit()
        .help("Current page. Type a number and press Return to go there.")
        .onAppear { showCurrentPage() }
        .onChange(of: isFocused) { editingChanged(isFocused) }
        .onChange(of: viewer.currentPage) {
            guard !isFocused else { return }
            showCurrentPage()
        }
    }

    private var fieldWidth: Double {
        max(Double("\(pageCount)".count) * 9 + 14, 30)
    }

    private func showCurrentPage() {
        text = "\(viewer.currentPage + 1)"
    }

    private func jump() {
        if let page = Int(text.trimmingCharacters(in: .whitespaces)), (1...pageCount).contains(page) {
            viewer.goToPage(page - 1)
        }
        isFocused = false
        showCurrentPage()
    }
}
