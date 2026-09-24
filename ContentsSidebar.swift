//
//  ContentsSidebar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import SwiftUI

/// Which list the sidebar beside the document is showing.
enum SidebarTab: String, CaseIterable, Identifiable {
    case thumbnails = "Thumbnails"
    case contents = "Contents"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .thumbnails: "rectangle.portrait.on.rectangle.portrait"
        case .contents: "list.bullet.indent"
        }
    }
}

/// The document's table of contents, in the sidebar beside the document in Read mode.
struct ContentsSidebar: View {
    /// The sidebar's width on this tab.
    ///
    /// Fixed rather than following the thumbnail size, because titles need room that a
    /// small thumbnail setting would not leave them.
    static let width = 240.0

    var body: some View {
        ContentUnavailableView(
            "No Table of Contents",
            systemImage: "list.bullet.indent",
            description: Text("This PDF doesn't list its sections.")
        )
    }
}
