//
//  TabStrip.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/5/26.
//

import SwiftUI

/// The row of tabs along the top of the window, one for each open PDF.
///
/// The plus button after the last tab opens a start tab, the same as File → New Tab.
struct TabStrip: View {
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(workspace.tabs) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: tab.id == workspace.selectedID,
                        select: { workspace.select(tab) },
                        close: { workspace.close(tab) }
                    )
                }

                Button {
                    workspace.openStart()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("New Tab")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)

            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// One tab in the strip.
///
/// Clicking it shows the tab, and the tab that is showing has a filled background. The
/// close button only appears on that tab and on the one under the pointer, so a row of
/// tabs is a row of names rather than a row of crosses.
private struct TabButton: View {
    let tab: WorkspaceTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200)

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
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 26)
        .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
        .contentShape(.rect)
        .onTapGesture(perform: select)
        .onHover { isHovered = $0 }
        .help(tab.title)
    }
}
