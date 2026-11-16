import CaffeineKit
import SwiftData
import SwiftUI

/// What to do when too much caffeine leaves you jittery or with a racing
/// heart, and when to stop reading and get help.
struct PalpitationGuideView: View {
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]
    @State private var showTense = false

    var body: some View {
        let status = Wellness.caffeineStatus(intakes, prefs: .current)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                emergency

                Card(title: "Şu an yapabileceklerin", symbol: "hand.raised.fill", tint: Theme.calm) {
                    tip("cup.and.saucer", "Bugün için kafeini burada bırak. Kola, enerji içeceği ve bitter çikolata da kafein içerir.")
                    tip("drop.fill", "Bir iki bardak su iç.")
                    tip("fork.knife", "Aç karnına içtiysen hafif bir şeyler ye.")
                    tip("wind", "Otur ve yavaş nefes al: 4 saniye al, 6 saniyede ver.")
                    tip("figure.walk", "Sakin, kısa bir yürüyüş titremeyi azaltabilir.")
                    Button { showTense = true } label: {
                        Label("2 dakikalık nefes egzersizini başlat", systemImage: "wind")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
                }

                Card(title: "Vücudundaki kafein", symbol: "cup.and.saucer.fill", tint: Theme.caffeine) {
                    Text("Şu an yaklaşık **\(status.nowMg.mgText)**.")
                    if let below = status.timeBelowThreshold, status.nowMg >= CaffeineModel.sleepThresholdMg {
                        Text("Tahminen **\(below.formatted(date: .omitted, time: .shortened))** civarında \(Int(CaffeineModel.sleepThresholdMg)) mg'nin altına iner. Etkiler genelde seviye düştükçe azalır.")
                    }
                    Text("Bugün toplam \(status.todayTotalMg.mgText); yaşına ve kilona göre günlük sınırın \(status.dailyLimitMg.mgText).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Card(title: "Bilmekte fayda var", symbol: "info.circle.fill", tint: Theme.sleep) {
                    tip("person.2", "Kafein hassasiyeti kişiden kişiye çok değişir. Bazı ilaçlar, hamilelik, doğum kontrol hapları ve karaciğer sağlığı kafeinin vücuttan atılmasını yavaşlatır.")
                    tip("calendar", "Çarpıntıyı sık yaşıyorsan ya da kafein azken de oluyorsa bir doktora danış.")
                    tip("info.circle", "Caffein tıbbi bir cihaz değildir; ritim bozukluğunu tespit edemez.")
                }
            }
            .padding(16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Çarpıntı rehberi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTense) { TenseFlowView() }
    }

    private var emergency: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hemen tıbbi yardım al", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Theme.alert)
            Text("Çarpıntıya şunlardan biri eşlik ediyorsa beklemeden acil yardım hattını (\(AppLinks.emergencyNumber)) ara:")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 6) {
                bullet("Göğüs ağrısı, baskı ya da sıkışma")
                bullet("Nefes darlığı")
                bullet("Bayılma, bayılacak gibi olma ya da şiddetli baş dönmesi")
                bullet("Dinlenmene rağmen dakikalarca geçmeyen çok hızlı ya da düzensiz kalp atışı")
            }
            .font(.subheadline)
            if let url = URL(string: "tel:\(AppLinks.emergencyNumber)") {
                Link(destination: url) {
                    Label("Acil yardım: \(AppLinks.emergencyNumber)", systemImage: "phone.fill")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.alert))
            }
        }
        .padding(18)
        .background(Theme.alert.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }

    private func tip(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text).font(.subheadline)
        }
    }
}
