import SwiftUI

/// Warm caramel for caffeine, night indigo for sleep, sage for calm and
/// a soft coral reserved for warnings. Every color has a light and dark
/// variant in the asset catalog.
enum Theme {
    static let caffeine = Color("Caffeine")
    static let sleep = Color("Sleep")
    static let calm = Color("Calm")
    static let alert = Color("Alert")
    static let canvas = Color("Canvas")
    static let card = Color("Card")
    /// Text on a filled tint: white in light mode, near-black in dark mode
    /// where the tints are lighter.
    static let onTint = Color("OnTint")
    static let ringTrack = Color.primary.opacity(0.08)
}

/// Rounded card used on every main screen.
struct Card<Content: View>: View {
    var title: LocalizedStringKey
    var symbol: String
    var tint: Color = Theme.caffeine
    /// When set, the header (title and icon) becomes a button.
    var headerAction: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let headerAction {
                Button(action: headerAction) { header }
                    .buttonStyle(.plain)
            } else {
                header
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var header: some View {
        HStack {
            Label {
                Text(title).font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint)
                    .font(headerAction == nil ? .body : .title3)
            }
            .foregroundStyle(.secondary)
            if headerAction != nil {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Big primary action button in a given tint.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.caffeine

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.onTint)
            .background(tint.opacity(configuration.isPressed ? 0.75 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// "Title ›" style for small inline links.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

/// Selectable chip for 1–5 scales and options.
struct ChoiceChip: View {
    var title: String
    var isSelected: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? tint.opacity(0.22) : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? tint : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
