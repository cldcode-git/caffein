import CaffeineKit
import SwiftUI

/// Age and weight wheels, the pregnancy toggle and a live preview of the
/// resulting daily limit. Used at onboarding, in Settings and from Today.
struct ProfileFields: View {
    @Binding var age: Int
    @Binding var weight: Int
    @Binding var pregnant: Bool

    static let ages = Array(13...100)
    static let weights = Array(30...200)

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                wheel(title: "Yaş") {
                    Picker("Yaş", selection: $age) {
                        ForEach(Self.ages, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                    }
                }
                wheel(title: "Kilo") {
                    Picker("Kilo", selection: $weight) {
                        ForEach(Self.weights, id: \.self) { Text(verbatim: "\($0) kg").tag($0) }
                    }
                }
            }
            Toggle("Hamileyim ya da emziriyorum", isOn: $pregnant)
                .font(.subheadline)
                .tint(Theme.caffeine)

            let result = CaffeineLimit.daily(for: CaffeineProfile(age: age, weightKg: Double(weight),
                                                                  pregnantOrBreastfeeding: pregnant))
            VStack(alignment: .leading, spacing: 4) {
                Text("Sana göre günlük kafein sınırı: \(result.dailyMg.mgText)")
                    .font(.headline)
                    .foregroundStyle(Theme.caffeine)
                Text(LimitText.basis(result.basis))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.caffeine.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func wheel<P: View>(title: LocalizedStringKey, @ViewBuilder picker: () -> P) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            picker()
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Stand-alone editor for Settings and the Today prompt.
struct ProfileView: View {
    @AppStorage(SettingsKey.profileAge) private var storedAge = 0
    @AppStorage(SettingsKey.profileWeight) private var storedWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var storedPregnant = false
    @Environment(\.dismiss) private var dismiss

    @State private var age = 30
    @State private var weight = 70
    @State private var pregnant = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Günlük kafein sınırın yaşına ve kilona göre hesaplanır. Bu bilgiler yalnızca bu telefonda kalır.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProfileFields(age: $age, weight: $weight, pregnant: $pregnant)
                Button("Kaydet") {
                    storedAge = age
                    storedWeight = Double(weight)
                    storedPregnant = pregnant
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.caffeine))
            }
            .padding(20)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Yaş ve kilo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if storedAge > 0 { age = storedAge }
            if storedWeight > 0 { weight = Int(storedWeight.rounded()) }
            pregnant = storedPregnant
        }
    }
}

enum LimitText {
    static func basis(_ basis: CaffeineLimit.Basis) -> String {
        switch basis {
        case .generalReference:
            L("Yaşını ve kilonu girene kadar sağlıklı yetişkinler için genel referans olan 400 mg kullanılır.")
        case .adultWeight:
            L("Yetişkinler için kilo başına yaklaşık 5,7 mg: EFSA'nın 70 kg'lık bir yetişkin için önerdiği 400 mg'nin kilona göre karşılığı.")
        case .adultCap:
            L("Yetişkinler için önerilen üst sınır olan 400 mg. Kilo arttıkça bu sınır yükselmez.")
        case .youthWeight:
            L("18 yaş altında kilo başına 3 mg (EFSA).")
        case .pregnancy:
            L("Hamilelik ve emzirme döneminde önerilen en fazla 200 mg.")
        }
    }
}
