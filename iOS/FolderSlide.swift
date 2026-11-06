import SwiftUI

@MainActor @Observable final class FolderSlide {
    private static var pauseBeforeSwap: Duration { .milliseconds(40) }

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

        var departureEdge: Edge {
            switch self {
            case .back: .trailing
            case .forward: .leading
            }
        }
    }

    private enum Position {
        case resting
        case following(Direction, distance: Double)
        case leaving(Direction, distance: Double)
    }

    private var position = Position.resting
    private(set) var arrivalEdge = Edge.trailing
    private(set) var departureEdge = Edge.leading
    var width = 0.0

    var offset: Double {
        switch position {
        case .resting: 0
        case .following(let direction, let distance), .leaving(let direction, let distance): direction.sign * distance
        }
    }

    func follow(_ direction: Direction, distance: Double) {
        if case .leaving = position { return }
        position = .following(direction, distance: max(distance, 0))
    }

    func settle() {
        if case .leaving = position { return }
        withAnimation(.snappy) { position = .resting }
    }

    func leave(_ direction: Direction, then move: @escaping () -> Void) {
        let distance: Double
        switch position {
        case .leaving: return
        case .resting: distance = 0
        case .following(_, let followed): distance = followed
        }
        position = .leaving(direction, distance: distance)
        arrivalEdge = direction.arrivalEdge
        departureEdge = direction.departureEdge
        Task {
            try? await Task.sleep(for: Self.pauseBeforeSwap)
            move()
            position = .resting
        }
    }
}
