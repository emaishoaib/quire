//
//  TabStrip.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/5/26.
//

import AppKit
import SwiftUI

/// The row of tabs in the window's title bar, one for each open PDF.
///
/// The tabs share the width between them. Each is as wide as it likes while there is
/// room, and they all narrow together, shortening their names, once there is not.
///
/// Dragging a tab along the strip reorders it. The tab follows the pointer, and the
/// others step aside as it passes over them, so the order on release is the order shown.
///
/// The real order does not change until the tab is let go. While it is held the tabs are
/// only drawn out of place, each shifted by an offset. Changing the order mid-drag has
/// the strip animate the dragged tab to its new place while the pointer is also moving
/// it, and the two disagree for a moment, which shows as the tab jumping away and back.
///
/// The plus button after the last tab opens a start tab, the same as File → New Tab.
/// The empty stretch after it stands in for the title bar this strip covers: dragging
/// it moves the window, and double-clicking it does what the user has set a title bar's
/// double-click to do.
struct TabStrip: View {
    /// How tabs arrive, leave and make room for one another.
    static let animation = Animation.spring(duration: 0.26, bounce: 0.1)

    /// A tab being dragged.
    ///
    /// `origin` is its place in the order, which stays its place until the drag is over.
    /// `target` is the place it would take if let go now. `isSettling` is true from the
    /// release until the tab has slid into that place.
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
    @State private var tabWidth = 0.0

    /// The distance from one tab's leading edge to the next one's.
    ///
    /// One figure serves for every tab, because the tabs share the width equally.
    private var step: Double { tabWidth + Self.spacing }

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
                        tabWidth = width
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

    /// How far a tab is drawn from its place in the order while a drag is going on.
    ///
    /// The dragged tab is at the pointer. The tabs between where it started and where it
    /// would land are one step over, towards the gap it left.
    private func dragOffset(for tab: WorkspaceTab, at index: Int) -> Double {
        guard let drag else { return 0 }

        if drag.id == tab.id {
            return drag.translation
        }
        if index > drag.origin && index <= drag.target {
            return -step
        }
        if index < drag.origin && index >= drag.target {
            return step
        }
        return 0
    }

    /// Follows the pointer with a tab, and works out where it would land.
    ///
    /// The distance is held between the first and last places, so a tab cannot be pulled
    /// off either end of the row. Only a change of landing place is animated, which is
    /// what slides the other tabs aside. The dragged tab itself is left out of that, or
    /// it would lag behind the pointer.
    private func dragGesture(for tab: WorkspaceTab) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if drag == nil {
                    guard step > 0, let index = workspace.tabs.firstIndex(where: { $0.id == tab.id }) else { return }
                    drag = TabDrag(id: tab.id, origin: index, target: index, translation: 0)
                    workspace.select(tab)
                }
                guard let current = drag, current.id == tab.id, !current.isSettling else { return }

                let lowest = Double(-current.origin) * step
                let highest = Double(workspace.tabs.count - 1 - current.origin) * step
                let translation = min(max(value.translation.width, lowest), highest)
                let target = current.origin + Int((translation / step).rounded())

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
                    drag?.translation = Double(current.target - current.origin) * step
                } completion: {
                    finishDrag(of: tab, at: current.target)
                }
            }
    }

    /// Makes the order that is being shown the real one, once the tab has settled.
    ///
    /// Animations are off for this. Every tab is already drawn where the new order puts
    /// it, so the order and the offsets change together and nothing is seen to move.
    private func finishDrag(of tab: WorkspaceTab, at index: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            workspace.move(tab, to: index)
            drag = nil
        }
    }

    /// Zooms or minimises the window, whichever System Settings says a double-click on a
    /// title bar should do.
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

/// One tab in the strip.
///
/// Clicking it shows the tab. The showing tab has a filled background, and the tab under
/// the pointer a fainter one.
///
/// The spot at the tab's trailing edge shows one thing at a time, and never changes
/// size, so the tabs do not shift about as it changes.
private struct TabButton: View {
    /// What the spot at the trailing edge is showing.
    ///
    /// The number comes first, because it is only there while Command is held. The dot
    /// gives way to the close button under the pointer, so an unsaved tab can still be
    /// closed with a click.
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
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(tab.title)
    }
}
