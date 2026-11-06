import SwiftUI

extension View {
    func folderSwipe(
        _ slide: FolderSlide,
        canGoBack: Bool,
        canGoForward: Bool,
        goBack: @escaping () -> Void,
        goForward: @escaping () -> Void
    ) -> some View {
        modifier(FolderSwipe(slide: slide, canGoBack: canGoBack, canGoForward: canGoForward, goBack: goBack, goForward: goForward))
    }
}

private struct FolderSwipe: ViewModifier {
    private static var shareOfWidthToMove: Double { 1.0 / 3 }
    private static var flickPointsPerSecond: Double { 500 }

    private enum Drag {
        case resting
        case ignored
        case following(FolderSlide.Direction)
    }

    let slide: FolderSlide
    let canGoBack: Bool
    let canGoForward: Bool
    let goBack: () -> Void
    let goForward: () -> Void

    @State private var drag = Drag.resting

    func body(content: Content) -> some View {
        content
            .offset(x: slide.offset)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { slide.width = $0 }
            .simultaneousGesture(swipe, isEnabled: canGoBack || canGoForward)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                switch drag {
                case .ignored:
                    return
                case .resting:
                    guard let direction = direction(of: value.translation) else { drag = .ignored; return }
                    drag = .following(direction)
                    slide.follow(direction, distance: abs(value.translation.width))
                case .following(let direction):
                    slide.follow(direction, distance: value.translation.width * direction.sign)
                }
            }
            .onEnded { value in
                defer { drag = .resting }
                guard case .following(let direction) = drag else { return }
                let distance = value.translation.width * direction.sign
                let isFlick = value.velocity.width * direction.sign > Self.flickPointsPerSecond
                guard distance > slide.width * Self.shareOfWidthToMove || isFlick else {
                    slide.settle()
                    return
                }
                switch direction {
                case .back: slide.leave(.back, then: goBack)
                case .forward: slide.leave(.forward, then: goForward)
                }
            }
    }

    private func direction(of translation: CGSize) -> FolderSlide.Direction? {
        guard abs(translation.width) > abs(translation.height) else { return nil }
        if translation.width > 0 { return canGoBack ? .back : nil }
        return canGoForward ? .forward : nil
    }
}
