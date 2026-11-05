import SwiftUI

extension View {
    func folderSwipe(
        canGoBack: Bool,
        canGoForward: Bool,
        goBack: @escaping () async -> Void,
        goForward: @escaping () async -> Void
    ) -> some View {
        modifier(FolderSwipe(canGoBack: canGoBack, canGoForward: canGoForward, goBack: goBack, goForward: goForward))
    }
}

private struct FolderSwipe: ViewModifier {
    private static var shareOfWidthToMove: Double { 1.0 / 3 }
    private static var flickPointsPerSecond: Double { 500 }

    private enum Direction {
        case back
        case forward

        var sign: Double {
            switch self {
            case .back: 1
            case .forward: -1
            }
        }
    }

    private enum Drag: Equatable {
        case resting
        case ignored
        case following(Direction, distance: Double)
    }

    let canGoBack: Bool
    let canGoForward: Bool
    let goBack: () async -> Void
    let goForward: () async -> Void

    @State private var drag = Drag.resting
    @State private var width = 0.0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(swipe, isEnabled: canGoBack || canGoForward)
    }

    private var offset: Double {
        guard case .following(let direction, let distance) = drag else { return 0 }
        return direction.sign * distance
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                switch drag {
                case .ignored:
                    return
                case .resting:
                    guard let direction = direction(of: value.translation) else { drag = .ignored; return }
                    drag = .following(direction, distance: abs(value.translation.width))
                case .following(let direction, _):
                    drag = .following(direction, distance: max(value.translation.width * direction.sign, 0))
                }
            }
            .onEnded { value in
                guard case .following(let direction, let distance) = drag else { drag = .resting; return }
                let isFlick = value.velocity.width * direction.sign > Self.flickPointsPerSecond
                guard distance > width * Self.shareOfWidthToMove || isFlick else {
                    withAnimation(.snappy) { drag = .resting }
                    return
                }
                slideAway(direction)
            }
    }

    private func direction(of translation: CGSize) -> Direction? {
        guard abs(translation.width) > abs(translation.height) else { return nil }
        if translation.width > 0 { return canGoBack ? .back : nil }
        return canGoForward ? .forward : nil
    }

    private func slideAway(_ direction: Direction) {
        withAnimation(.snappy(duration: 0.2)) {
            drag = .following(direction, distance: width)
        } completion: {
            Task {
                switch direction {
                case .back: await goBack()
                case .forward: await goForward()
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { drag = .resting }
            }
        }
    }
}
