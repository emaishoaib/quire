//
//  ZoomControl.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

/// The zoom and view controls that float in the bottom-right of the Read view.
///
/// The percentage opens a menu holding the page layout options and the fit modes,
/// with minus and plus either side for stepping through zoom levels.
struct ZoomControl: View {
    let viewer: ViewerController

    private let presets: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4]

    var body: some View {
        HStack(spacing: 2) {
            stepper("Zoom Out", systemImage: "minus") { viewer.zoomOut() }

            Menu {
                Toggle("Single-Page View", isOn: binding(viewer.isTwoUp == false) { viewer.setTwoUp(!$0) })
                Toggle("Two-Page View", isOn: binding(viewer.isTwoUp) { viewer.setTwoUp($0) })
                Toggle("Show Cover Page", isOn: binding(viewer.showsCoverPage) { viewer.setShowsCoverPage($0) })
                    .disabled(!viewer.isTwoUp)

                Divider()

                Toggle("Enable Scrolling", isOn: binding(viewer.isContinuous) { viewer.setContinuous($0) })

                Divider()

                Button("Actual Size") { viewer.setScale(1) }
                Button("Zoom to Page Level") { viewer.fitPage() }
                Button("Fit to Width") { viewer.fitWidth() }
                Button("Fit Height") { viewer.fitHeight() }

                Divider()

                ForEach(presets, id: \.self) { preset in
                    Button(Self.percentage(preset)) { viewer.setScale(preset) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(Self.percentage(viewer.scale))
                        .font(.system(size: 13))
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 66, height: FloatingCapsule.contentHeight)
                .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Zoom and page layout")

            stepper("Zoom In", systemImage: "plus") { viewer.zoomIn() }
        }
        .floatingCapsule()
    }

    private func stepper(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: FloatingCapsule.contentHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func binding(_ value: Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: set)
    }

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
