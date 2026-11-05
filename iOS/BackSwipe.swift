import SwiftUI

extension View {
    func backSwipe(isEnabled: Bool, goBack: @escaping () async -> Void) -> some View {
        modifier(BackSwipe(isEnabled: isEnabled, goBack: goBack))
    }
}

private struct BackSwipe: ViewModifier {
    private static var shareOfWidthToGoBack: Double { 1.0 / 3 }
    private static var flickPointsPerSecond: Double { 500 }

    private enum Drag: Equatable {
        case resting
        case ignored
        case following(distance: Double)
    }

    let isEnabled: Bool
    let goBack: () async -> Void

    @State private var drag = Drag.resting
    @State private var width = 0.0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(swipe, isEnabled: isEnabled)
    }

    private var offset: Double {
        guard case .following(let distance) = drag else { return 0 }
        return distance
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                switch drag {
                case .ignored:
                    return
                case .resting:
                    let isRightward = value.translation.width > abs(value.translation.height)
                    drag = isRightward ? .following(distance: value.translation.width) : .ignored
                case .following:
                    drag = .following(distance: max(value.translation.width, 0))
                }
            }
            .onEnded { value in
                guard case .following(let distance) = drag else { drag = .resting; return }
                let isFlick = value.velocity.width > Self.flickPointsPerSecond
                guard distance > width * Self.shareOfWidthToGoBack || isFlick else {
                    withAnimation(.snappy) { drag = .resting }
                    return
                }
                slideAway()
            }
    }

    private func slideAway() {
        withAnimation(.snappy(duration: 0.2)) {
            drag = .following(distance: width)
        } completion: {
            Task {
                await goBack()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { drag = .resting }
            }
        }
    }
}
