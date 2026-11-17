import CaffeineKit
import SwiftUI

/// A drink the user picked, waiting for count and time.
struct DrinkChoice: Identifiable, Hashable {
    let id = UUID()
    let drink: Drink
    /// Set for custom drinks; catalog drinks use their localized name.
    let customName: String?

    var displayName: String { customName ?? DrinkText.name(drink.id) ?? drink.id }

    static func == (a: DrinkChoice, b: DrinkChoice) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Asks how many servings and when, since people often log a drink well
/// after they had it. "Now" is the default and one tap away.
struct AddDrinkForm: View {
    let choice: DrinkChoice
    let add: (_ servings: Int, _ date: Date) -> Void

    @State private var servings = 1
    @State private var pickedTime = Date()
    @State private var isNow = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    Text("Kaç tane?").font(.headline)
                    HStack {
                        Text("Toplam \((choice.drink.caffeineMg * Double(servings)).mgText)")
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                        Spacer()
                        CountStepper(value: servings, accessibilityName: choice.displayName,
                                     decrement: { servings -= 1 }, increment: { servings += 1 })
                            .scaleEffect(1.15)
                    }
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ne zaman içtin?").font(.headline)
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.snappy) {
                                pickedTime = Date()
                                isNow = true
                            }
                        } label: {
                            Label("Şimdi", systemImage: isNow ? "checkmark.circle.fill" : "clock")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(isNow ? Theme.caffeine.opacity(0.18) : Color.primary.opacity(0.06),
                                            in: Capsule())
                                .overlay(Capsule().stroke(isNow ? Theme.caffeine : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isNow ? Theme.caffeine : .primary)

                        Spacer()

                        DatePicker("Saat", selection: Binding(
                            get: { pickedTime },
                            set: { pickedTime = $0; isNow = false }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                    if !isNow, Self.isYesterday(Self.resolve(pickedTime)) {
                        Text("Dün \(Self.resolve(pickedTime).clockText) olarak kaydedilecek.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("Ekle") {
                    add(servings, isNow ? Date() : Self.resolve(pickedTime))
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.caffeine))
            }
            .padding(20)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("İçecek ekle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: choice.drink.symbol)
                .font(.title2)
                .foregroundStyle(Theme.caffeine)
                .frame(width: 52, height: 52)
                .background(Theme.caffeine.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.displayName).font(.title3.weight(.semibold))
                if choice.customName == nil {
                    Text(DrinkText.serving(choice.drink.id))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("1 adet: \(choice.drink.caffeineMg.mgText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The picker only shows a clock time; a time later than now means the
    /// drink was had the evening before (e.g. logging 23:30 at 01:00).
    static func resolve(_ picked: Date, now: Date = Date()) -> Date {
        picked > now.addingTimeInterval(60) ? picked.addingTimeInterval(-86_400) : picked
    }

    static func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }
}
