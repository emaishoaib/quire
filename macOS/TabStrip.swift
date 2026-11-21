import AppKit
import SwiftUI

struct TabStrip: View {
    static let animation = Animation.spring(duration: 0.26, bounce: 0.1)

    private struct TabDrag {
        let id: WorkspaceTab.ID
        let origin: Int
        var target: Int
        var translation: Double
        var isSettling = false
    }

    private static let spacing = 3.0

    let workspace: Workspace

    @State private var drag: TabDrag?
    @State private var tabWidths: [WorkspaceTab.ID: Double] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Self.spacing) {
                ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabButton(
                        tab: tab,
                        isSelected: tab.id == workspace.selectedID,
                        number: workspace.showsTabNumbers && index < Workspace.numberedTabs ? index + 1 : nil,
                        select: { workspace.select(tab) },
                        close: { workspace.close(tab) }
                    )
                    .onGeometryChange(for: Double.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        tabWidths[tab.id] = width
                    }
                    .onDisappear {
                        tabWidths[tab.id] = nil
                    }
                    .offset(x: dragOffset(for: tab, at: index))
                    .transaction { transaction in
                        if let drag, drag.id == tab.id, !drag.isSettling {
                            transaction.animation = nil
                        }
                    }
                    .zIndex(drag?.id == tab.id ? 1 : 0)
                    .simultaneousGesture(dragGesture(for: tab))
                    .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                }

                Button {
                    workspace.openStart()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("New Tab")

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(WindowDragGesture())
                    .simultaneousGesture(TapGesture(count: 2).onEnded(titleBarDoubleClick))
            }
            .padding(.leading, workspace.stripLeadingInset)
            .padding(.trailing, 8)
            .animation(Self.animation, value: Set(workspace.tabs.map(\.id)))
            .animation(Self.animation, value: workspace.stripLeadingInset)

            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipped()
    }

    private func dragOffset(for tab: WorkspaceTab, at index: Int) -> Double {
        guard let drag else { return 0 }

        if drag.id == tab.id {
            return drag.translation
        }
        let shift = (tabWidths[drag.id] ?? 0) + Self.spacing
        if index > drag.origin && index <= drag.target {
            return -shift
        }
        if index < drag.origin && index >= drag.target {
            return shift
        }
        return 0
    }

    private func width(at index: Int) -> Double {
        tabWidths[workspace.tabs[index].id] ?? 0
    }

    /// How far a tab dragged from `origin` travels to sit in the slot at `target`, past the tabs in between.
    private func distance(from origin: Int, to target: Int) -> Double {
        if target > origin {
            (origin + 1...target).reduce(0) { $0 + width(at: $1) + Self.spacing }
        } else if target < origin {
            -(target..<origin).reduce(0) { $0 + width(at: $1) + Self.spacing }
        } else {
            0
        }
    }

    /// The slot a tab dragged from `origin` lands in, which changes once it is past the middle of a neighbour.
    private func slot(from origin: Int, at translation: Double) -> Int {
        var target = origin
        while target + 1 < workspace.tabs.count,
              translation > distance(from: origin, to: target) + (width(at: target + 1) + Self.spacing) / 2 {
            target += 1
        }
        while target > 0,
              translation < distance(from: origin, to: target) - (width(at: target - 1) + Self.spacing) / 2 {
            target -= 1
        }
        return target
    }

    private func dragGesture(for tab: WorkspaceTab) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if drag == nil {
                    guard tabWidths[tab.id] != nil, let index = workspace.tabs.firstIndex(where: { $0.id == tab.id }) else { return }
                    drag = TabDrag(id: tab.id, origin: index, target: index, translation: 0)
                    workspace.select(tab)
                }
                guard let current = drag, current.id == tab.id, !current.isSettling else { return }

                let lowest = distance(from: current.origin, to: 0)
                let highest = distance(from: current.origin, to: workspace.tabs.count - 1)
                let translation = min(max(value.translation.width, lowest), highest)
                let target = slot(from: current.origin, at: translation)

                drag?.translation = translation
                if target != current.target {
                    withAnimation(Self.animation) {
                        drag?.target = target
                    }
                }
            }
            .onEnded { _ in
                guard let current = drag, current.id == tab.id, !current.isSettling else { return }

                withAnimation(Self.animation) {
                    drag?.isSettling = true
                    drag?.translation = distance(from: current.origin, to: current.target)
                } completion: {
                    finishDrag(of: tab, at: current.target)
                }
            }
    }

    private func finishDrag(of tab: WorkspaceTab, at index: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            workspace.move(tab, to: index)
            drag = nil
        }
    }

    private func titleBarDoubleClick() {
        guard let window = NSApp.keyWindow else { return }

        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize":
            window.performMiniaturize(nil)
        case "None":
            break
        default:
            window.performZoom(nil)
        }
    }
}

private struct TabButton: View {
    private enum Accessory: Equatable {
        case number(Int)
        case unsavedDot
        case closeButton
    }

    let tab: WorkspaceTab
    let isSelected: Bool
    let number: Int?
    let select: () -> Void
    let close: () -> Void

    @State private var isHovered = false

    private var accessory: Accessory {
        if let number {
            .number(number)
        } else if tab.isEdited && !isHovered {
            .unsavedDot
        } else {
            .closeButton
        }
    }

    private var fill: Color {
        if isSelected {
            .primary.opacity(0.1)
        } else if isHovered {
            .primary.opacity(0.05)
        } else {
            .clear
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                switch accessory {
                case .number(let number):
                    Text("\(number)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(.quaternary, in: .rect(cornerRadius: 4))
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                case .unsavedDot:
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .frame(width: 16, height: 16)
                        .help("Unsaved changes")
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                case .closeButton:
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .opacity(isSelected || isHovered ? 1 : 0)
                    .help("Close Tab")
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.12), value: accessory)
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(maxWidth: 200)
        .frame(height: 26)
        .background(fill, in: .rect(cornerRadius: 6))
        .frame(maxHeight: .infinity)
        .contentShape(.rect)
        .onTapGesture(perform: select)
        .onMiddleClick(perform: close)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(tab.title)
    }
}
