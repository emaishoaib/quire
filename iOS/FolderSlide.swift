import SwiftUI

@MainActor @Observable final class FolderSlide {
    enum Direction {
        case back
        case forward

        var sign: Double {
            switch self {
            case .back: 1
            case .forward: -1
            }
        }

        var arrivalEdge: Edge {
            switch self {
            case .back: .leading
            case .forward: .trailing
            }
        }
    }

    private enum Position {
        case resting
        case following(Direction, distance: Double)
        case gone(Direction)
    }

    private var position = Position.resting
    private(set) var arrivalEdge = Edge.trailing
    var width = 0.0

    var offset: Double {
        switch position {
        case .resting: 0
        case .following(let direction, let distance): direction.sign * distance
        case .gone(let direction): direction.sign * width
        }
    }

    func follow(_ direction: Direction, distance: Double) {
        if case .gone = position { return }
        position = .following(direction, distance: max(distance, 0))
    }

    func settle() {
        if case .gone = position { return }
        withAnimation(.snappy) { position = .resting }
    }

    func leave(_ direction: Direction, then move: @escaping () -> Void) {
        if case .gone = position { return }
        arrivalEdge = direction.arrivalEdge
        withAnimation(.snappy(duration: 0.2)) {
            position = .gone(direction)
        } completion: {
            move()
            self.position = .resting
        }
    }
}
