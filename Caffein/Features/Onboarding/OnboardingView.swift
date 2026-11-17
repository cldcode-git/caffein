import CaffeineKit
import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0
    @AppStorage(SettingsKey.bedtimeMinutes) private var bedtimeMinutes = 23 * 60
    @AppStorage(SettingsKey.profileAge) private var storedAge = 0
    @AppStorage(SettingsKey.profileWeight) private var storedWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var storedPregnant = false
    @AppStorage(SettingsKey.sex) private var storedSex = BiologicalSex.unspecified.rawValue

    @State private var age = 30
    @State private var weight = 70
    @State private var pregnant = false
    @State private var sex = BiologicalSex.unspecified

    private let lastPage = 4

    var body: some View {
        VStack {
            TabView(selection: $page) {
                card(symbol: "cup.and.saucer.fill", tint: Theme.caffeine,
                     title: "Kahveni bırakma, tanı",
                     text: "Caffein, kafeinin uykuna ve gerginliğine sende nasıl etki ettiğini gösterir. Amaç kafeini yasaklamak değil, sana iyi gelen dengeyi bulmak.")
                    .tag(0)
                card(symbol: "sunrise.fill", tint: Theme.sleep,
                     title: "Günde birkaç dokunuş",
                     text: "Sabah 60 saniyelik nabız ve iki soru. Gün içinde içtiğin her şeyi tek dokunuşla ekle. Akşam günün gerginliğine puan ver.")
                    .tag(1)
                card(symbol: "lock.fill", tint: Theme.calm,
                     title: "Verin sende kalır",
                     text: "Akıllı saat gerekmez, hesap açman gerekmez. Her şey yalnızca bu telefonda saklanır. Caffein bir sağlıklı yaşam uygulamasıdır, tıbbi cihaz değildir.")
                    .tag(2)
                profile.tag(3)
                setup.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < lastPage ? "Devam" : "Başla") {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    storedAge = age
                    storedWeight = Double(weight)
                    storedPregnant = pregnant
                    storedSex = sex.rawValue
                    onFinish()
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: Theme.caffeine))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var profile: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.caffeine)
                    .padding(.top, 24)
                Text("Seni tanıyalım")
                    .font(.title2.weight(.semibold))
                Text("Sana uygun kafein miktarı ve nabzının senin için normal aralığı yaşına, kilona ve cinsiyetine göre değişir.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ProfileFields(age: $age, weight: $weight, pregnant: $pregnant, sex: $sex)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var setup: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.sleep)
            Text("Uyku saatin")
                .font(.title2.weight(.semibold))
            Text("Son kahve saatini buna göre hesaplıyoruz.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DatePicker("Genelde kaçta yatarsın?", selection: Binding(
                get: { DayClock.date(from: bedtimeMinutes) },
                set: { bedtimeMinutes = DayClock.minutes(from: $0) }
            ), displayedComponents: .hourAndMinute)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            Text("Bunu ve uygulama dilini sonra Ayarlar'dan değiştirebilirsin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
    }

    private func card(symbol: String, tint: Color, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 60))
                .foregroundStyle(tint)
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
