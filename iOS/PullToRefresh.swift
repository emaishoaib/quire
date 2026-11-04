import SwiftUI

struct PullToRefreshScrollView<Content: View>: View {
    private static var threshold: Double { 70 }
    private static var headerHeight: Double { 64 }
    private static var shortestRefresh: Duration { .milliseconds(700) }

    private enum Pull: Equatable {
        case resting
        case dragging(distance: Double)
        case refreshing
    }

    let refresh: () async -> Void
    @ViewBuilder let content: Content

    @State private var pull = Pull.resting

    var body: some View {
        ScrollView {
            content
        }
        .contentMargins(.top, pull == .refreshing ? Self.headerHeight : 0, for: .scrollContent)
        .onScrollGeometryChange(for: Double.self) { -($0.contentOffset.y + $0.contentInsets.top) } action: { _, distance in
            guard pull != .refreshing else { return }
            pull = distance > 0 ? .dragging(distance: distance) : .resting
        }
        .onScrollPhaseChange { old, new in
            guard old == .interacting, new != .interacting else { return }
            guard case .dragging(let distance) = pull, distance >= Self.threshold else { return }
            startRefresh()
        }
        .overlay(alignment: .top) { header }
    }

    @ViewBuilder
    private var header: some View {
        switch pull {
        case .resting:
            EmptyView()
        case .dragging(let distance):
            RefreshHeader(state: distance >= Self.threshold ? .release : .pull)
                .frame(height: Self.headerHeight)
                .opacity(min(distance / Self.threshold, 1))
        case .refreshing:
            RefreshHeader(state: .refreshing)
                .frame(height: Self.headerHeight)
                .transition(.opacity)
        }
    }

    private func startRefresh() {
        withAnimation(.snappy) { pull = .refreshing }
        Task {
            let deadline = ContinuousClock.now + Self.shortestRefresh
            await refresh()
            try? await Task.sleep(until: deadline, clock: .continuous)
            withAnimation(.snappy) { pull = .resting }
        }
    }
}

private struct RefreshHeader: View {
    enum State {
        case pull
        case release
        case refreshing
    }

    let state: State

    var body: some View {
        VStack(spacing: 6) {
            switch state {
            case .pull, .release:
                Image(systemName: "arrow.down")
                    .rotationEffect(.degrees(state == .release ? 180 : 0))
                    .animation(.snappy, value: state == .release)
            case .refreshing:
                ProgressView()
                    .tint(Color.cream)
            }

            Text(title)
                .font(.caption)
        }
        .foregroundStyle(Color.cream.opacity(0.8))
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch state {
        case .pull: "Pull to refresh"
        case .release: "Release to refresh"
        case .refreshing: "Refreshing your library…"
        }
    }
}
