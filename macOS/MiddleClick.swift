import AppKit
import SwiftUI

extension View {
    /// Runs an action when the middle mouse button clicks this view, and lets every other click through to the view underneath.
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        overlay(MiddleClickCatcher(action: action))
    }
}

private struct MiddleClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> MiddleClickView {
        MiddleClickView()
    }

    func updateNSView(_ view: MiddleClickView, context: Context) {
        view.action = action
    }
}

private final class MiddleClickView: NSView {
    private static let middleButton = 2

    var action: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent, Self.isMiddleClick(event) else { return nil }
        return super.hitTest(point)
    }

    override func otherMouseDown(with event: NSEvent) {}

    override func otherMouseUp(with event: NSEvent) {
        guard Self.isMiddleClick(event), bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        action?()
    }

    private static func isMiddleClick(_ event: NSEvent) -> Bool {
        [.otherMouseDown, .otherMouseUp].contains(event.type) && event.buttonNumber == middleButton
    }
}
