//
//  TabStrip.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/5/26.
//

import SwiftUI

/// The row of tabs along the top of the window, one for each open PDF.
///
/// Clicking a tab shows it. The tab that is showing is the one with a filled background.
struct TabStrip: View {
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(workspace.tabs) { tab in
                    button(for: tab)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)

            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func button(for tab: WorkspaceTab) -> some View {
        let isSelected = tab.id == workspace.selectedID

        return Button {
            workspace.select(tab)
        } label: {
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .frame(maxWidth: 220)
                .frame(height: 26)
                .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }
}
