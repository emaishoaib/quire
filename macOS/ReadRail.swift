import SwiftUI

struct ReadRail: View {
    let viewer: ViewerController
    let ocr: OCRRunner
    let model: PDFModel
    let find: () -> Void
    @Binding var mode: Mode
    @Binding var showsThumbnails: Bool

    static let width = 62.0

    var body: some View {
        VStack(spacing: 8) {
            button("Find", systemImage: "magnifyingglass", action: find)

            separator

            button(
                mode == .read ? "Organise Pages" : "Read",
                systemImage: mode == .read ? "square.grid.2x2" : "doc.text"
            ) {
                withAnimation(Mode.animation) {
                    mode = mode == .read ? .pages : .read
                }
            }

            if mode == .read {
                button("Show or Hide Sidebar", systemImage: "sidebar.left") {
                    showsThumbnails.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .transition(.opacity)
            }

            separator

            button("Recognize text: make scanned pages searchable", systemImage: "text.viewfinder") {
                ocr.run(on: model)
            }
            .disabled(model.pageCount == 0 || ocr.isRunning)

            if mode == .read {
                button(
                    viewer.isHighlighting ? "Stop Highlighting" : "Highlight: drag across text to highlight it",
                    systemImage: "highlighter"
                ) {
                    withAnimation(HighlightPalette.animation) {
                        viewer.setHighlighting(!viewer.isHighlighting)
                    }
                }
                .foregroundStyle(viewer.isHighlighting ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .background(.tint.opacity(viewer.isHighlighting ? 0.18 : 0), in: .rect(cornerRadius: 7))
                .anchorPreference(key: HighlightButtonKey.self, value: .bounds) { $0 }
                .transition(.opacity)
            }

            Spacer(minLength: 20)

            if mode == .read {
                Group {
                    PageIndicator(viewer: viewer, pageCount: model.pageCount)

            separator

            VStack(spacing: 0) {
                indicator("chevron.up")

                Menu {
                    Button("Fit Page") { viewer.fitPage() }
                    Button("Fit Width") { viewer.fitWidth() }
                    Button("Fit Height") { viewer.fitHeight() }
                    Divider()
                    ForEach([0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4], id: \.self) { preset in
                        Button(ZoomControl.percentage(preset)) { viewer.setScale(preset) }
                    }
                } label: {
                    Text(ZoomControl.percentage(viewer.scale))
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 22)
                .help("Zoom level and fit options")

                indicator("chevron.down")
            }

            button("Actual Size", systemImage: "1.magnifyingglass") { viewer.setScale(1) }

            button("Zoom In", systemImage: "plus.magnifyingglass") { viewer.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)

                    button("Zoom Out", systemImage: "minus.magnifyingglass") { viewer.zoomOut() }
                        .keyboardShortcut("-", modifiers: .command)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(width: Self.width)
        .background(.bar)
    }

    private var separator: some View {
        Divider()
            .frame(width: 26)
    }

    private func indicator(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(height: 10)
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .frame(width: 34, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
