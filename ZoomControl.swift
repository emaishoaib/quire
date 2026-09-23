//
//  ZoomControl.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

/// Formatting shared by the zoom controls.
enum ZoomControl {
    static func percentage(_ scale: Double) -> String {
        "\(Int((scale * 100).rounded()))%"
    }
}

/// The zoom readout that appears while the zoom level is changing and fades away after.
///
/// Pinch-zooming on the trackpad gives no feedback of its own, so this shows what the
/// level now is and offers a slider for landing on a particular one.
struct ZoomHUD: View {
    let viewer: ViewerController

    @State private var isVisible = false
    @State private var isHeld = false
    @State private var hideTask: Task<Void, Never>?

    private let range = -2.0...2.0

    var body: some View {
        VStack(spacing: 8) {
            Text(ZoomControl.percentage(viewer.scale))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .fixedSize()

            Rectangle()
                .fill(.separator)
                .frame(width: 32, height: 1)

            Slider(value: sliderValue, in: range) { editing in
                isHeld = editing
                if !editing {
                    scheduleHide()
                }
            }
            .controlSize(.small)
            .frame(width: 120)
            .rotationEffect(.degrees(-90))
            .frame(width: 24, height: 120)
        }
        .frame(width: 56)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .fixedSize()
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .opacity(isVisible || isHeld ? 1 : 0)
        .allowsHitTesting(isVisible || isHeld)
        .animation(.easeOut(duration: 0.15), value: isVisible || isHeld)
        .onHover { inside in
            isHeld = inside
            if !inside {
                scheduleHide()
            }
        }
        .onChange(of: viewer.scale) {
            isVisible = true
            scheduleHide()
        }
    }

    /// The slider works in powers of two, so each step feels the same size at any zoom level.
    private var sliderValue: Binding<Double> {
        Binding(
            get: { max(range.lowerBound, min(range.upperBound, log2(viewer.scale))) },
            set: { viewer.setScale(pow(2, $0)) }
        )
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !isHeld else { return }
            isVisible = false
        }
    }
}
