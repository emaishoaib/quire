import SwiftUI

struct ZoomMenu: View {
    private static let presets = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4]

    let viewer: ViewerController
    let width: Double
    let height: Double

    var body: some View {
        Menu {
            Button("Fit Width") { viewer.fitWidth() }
            Divider()
            ForEach(Self.presets, id: \.self) { preset in
                Button(percentage(preset)) { viewer.setScale(preset) }
            }
        } label: {
            Text(percentage(viewer.scale))
                .font(.system(size: 13))
                .monospacedDigit()
                .frame(width: width, height: height)
                .contentShape(.rect)
        }
        .accessibilityLabel("Zoom level and fit options")
    }

    private func percentage(_ scale: Double) -> String {
        scale.formatted(.percent.precision(.fractionLength(0)))
    }
}
