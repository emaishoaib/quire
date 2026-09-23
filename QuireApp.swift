//
//  QuireApp.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

@main
struct QuireApp: App {
    var body: some Scene {
        DocumentGroup { document in
            ContentView(document: document)
        } makeDocument: { configuration, context in
            QuireDocument()
        }
    }
}
