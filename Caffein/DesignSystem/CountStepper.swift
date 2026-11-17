import SwiftUI

/// A compact "− 2 +" control. The minus button is disabled at `minimum`;
/// set `minimum` to 0 when going below 1 should remove the item.
struct CountStepper: View {
    let value: Int
    var minimum = 1
    var maximum = 10
    /// What is being counted, for VoiceOver ("Espresso count").
    var accessibilityName: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            button("minus", enabled: value > minimum, action: decrement)
            Text(verbatim: "\(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(minWidth: 22)
                .contentTransition(.numericText(value: Double(value)))
            button("plus", enabled: value < maximum, action: increment)
        }
        .background(Theme.caffeine.opacity(0.12), in: Capsule())
        // A number line reads left to right in every language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accessibilityName) adedi"))
        .accessibilityValue(Text(verbatim: "\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value < maximum { increment() }
            case .decrement: if value > minimum { decrement() }
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.caffeine : Color.secondary.opacity(0.4))
        .disabled(!enabled)
    }
}
