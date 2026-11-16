import SwiftUI

/// Scrolling line of the filtered pulse signal, newest value on the right.
struct WaveformView: View {
    var values: [Double]
    var capacity: Int
    var tint: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, capacity > 1 else { return }
            let maxAbs = max(values.map(abs).max() ?? 0, 1e-9)
            let stepX = size.width / CGFloat(capacity - 1)
            let offset = capacity - values.count
            var path = Path()
            for (i, value) in values.enumerated() {
                let point = CGPoint(
                    x: CGFloat(i + offset) * stepX,
                    y: size.height / 2 - CGFloat(value / maxAbs) * size.height * 0.42
                )
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(tint),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
