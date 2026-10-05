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
/// The plus button after the last tab opens a start tab, the same as File → New Tab.
/// The empty stretch after it stands in for the title bar this strip covers: dragging
/// it moves the window, and double-clicking it does what the user has set a title bar's
/// double-click to do.
struct TabStrip: View {
    /// How tabs arrive, leave and make room for one another.
    static let animation = Animation.spring(duration: 0.26, bounce: 0.1)

    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabButton(
                        tab: tab,
                        isSelected: tab.id == workspace.selectedID,
                        number: workspace.showsTabNumbers && index < Workspace.numberedTabs ? index + 1 : nil,
                        select: { workspace.select(tab) },
                        close: { workspace.close(tab) }
                    )
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
            .animation(Self.animation, value: workspace.tabs.map(\.id))
            .animation(Self.animation, value: workspace.stripLeadingInset)

            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipped()
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
