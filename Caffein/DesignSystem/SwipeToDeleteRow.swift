import SwiftUI

/// A row that can be swiped toward its leading edge to reveal a delete
/// button, for lists that aren't a `List` (where `.swipeActions` isn't
/// available). A long swipe deletes straight away.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.layoutDirection) private var layoutDirection
    /// How far the row is pulled, in layout terms: 0 at rest, negative when
    /// pulled toward the leading edge.
    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var isDragging = false

    private let revealWidth: CGFloat = 72
    private let deleteDistance: CGFloat = 170

    /// Drag translations are in screen coordinates; in right-to-left
    /// layouts the leading edge is on the right.
    private var direction: CGFloat { layoutDirection == .rightToLeft ? -1 : 1 }

    var body: some View {
        content()
            .background(Theme.card)
            // While the button is showing, a tap on the row closes it again.
            .overlay {
                if offset < 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: close)
                }
            }
            .offset(x: offset)
            // On top of the row, so it gets the tap.
            .overlay(alignment: .trailing) {
                if offset < -4 {
                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: max(0, -offset - 6))
                            .frame(maxHeight: .infinity)
                            .background(Theme.alert, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .simultaneousGesture(drag)
            // VoiceOver users can't swipe the row; give them the action directly.
            .accessibilityAction(named: Text("Sil"), remove)
            .animation(isDragging ? nil : .snappy, value: offset)
    }

    private func close() {
        offset = 0
        startOffset = 0
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let dx = value.translation.width * direction
                guard isDragging || abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                isDragging = true
                let raw = startOffset + dx
                // Resist a little past the reveal width, and not at all the other way.
                offset = raw > 0 ? 0 : raw
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let predicted = startOffset + value.predictedEndTranslation.width * direction
                if offset < -deleteDistance || predicted < -deleteDistance * 1.6 {
                    remove()
                } else if offset < -revealWidth / 2 {
                    offset = -revealWidth
                } else {
                    offset = 0
                }
                startOffset = offset
            }
    }

    private func remove() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy) {
            offset = 0
            startOffset = 0
            onDelete()
        }
    }
}
