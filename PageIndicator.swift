import SwiftUI

struct PageIndicator: View {
    let viewer: ViewerController
    let pageCount: Int

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: fieldWidth, height: 24)
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
