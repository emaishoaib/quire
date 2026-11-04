import SwiftUI
import UIKit

struct Wordmark: View {
    private enum Mark {
        static let left = 120.0
        static let top = 175.0
        static let height = 670.0
        static let side = 1024.0
        static let textStart = 930.0
        static let baseline = 825.0
        static let fontSize = 800.0
        static let firstGap = 231.0
        static let gapCount = 8
        static let gapHeight = 30.0
        static let stripePitch = 76.0
        static let fadeIntoR = 0.25
        static let fadeCurve = 0.39
    }

    let height: Double

    private var scale: Double { height / Mark.height }

    private var width: Double {
        (Mark.textStart + Self.textWidth("uire") - Mark.left) * scale
    }

    var body: some View {
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Mark.left, y: -Mark.top)
            context.draw(Image("QuireMark"), in: CGRect(x: 0, y: 0, width: Mark.side, height: Mark.side))

            let text = context.resolve(
                Text("uire")
                    .font(.system(size: Mark.fontSize, weight: .bold))
                    .foregroundStyle(Color.cream)
            )
            let textSize = text.measure(in: CGSize(width: Mark.side * 4, height: Mark.side))
            let origin = CGPoint(x: Mark.textStart, y: Mark.baseline - text.lastBaseline(in: textSize))
            context.draw(text, in: CGRect(origin: origin, size: textSize))

            context.blendMode = .destinationOut
            context.fill(Self.gaps, with: .color(.black))
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("Quire")
    }

    private static var gaps: Path {
        let fadeEnd = Mark.textStart + textWidth("ui") + textWidth("r") * Mark.fadeIntoR
        let bend = Mark.textStart + (fadeEnd - Mark.textStart) * Mark.fadeCurve
        return Path { path in
            for row in 0..<Mark.gapCount {
                let top = Mark.firstGap + Double(row) * Mark.stripePitch
                let middle = top + Mark.gapHeight / 2
                path.move(to: CGPoint(x: Mark.textStart, y: top))
                path.addQuadCurve(to: CGPoint(x: fadeEnd, y: middle), control: CGPoint(x: bend, y: top + 9))
                path.addQuadCurve(to: CGPoint(x: Mark.textStart, y: top + Mark.gapHeight), control: CGPoint(x: bend, y: top + 21))
                path.closeSubpath()
            }
        }
    }

    private static func textWidth(_ string: String) -> Double {
        let font = UIFont.systemFont(ofSize: Mark.fontSize, weight: .bold)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}
