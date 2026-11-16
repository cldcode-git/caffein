import SwiftUI

/// Progress ring with a soft disc that swells on every detected beat.
struct PulseRing<Center: View>: View {
    var progress: Double
    var beatTick: Int
    var isActive: Bool
    var tint: Color
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
            Circle()
                .fill(tint.opacity(isActive ? 0.16 : 0.06))
                .padding(26)
                .phaseAnimator([1.0, 1.07], trigger: beatTick) { content, scale in
                    content.scaleEffect(scale)
                } animation: { scale in
                    scale > 1 ? .easeOut(duration: 0.1) : .easeIn(duration: 0.35)
                }
                .animation(.easeInOut(duration: 0.4), value: isActive)
            center
        }
        .accessibilityElement(children: .combine)
    }
}
