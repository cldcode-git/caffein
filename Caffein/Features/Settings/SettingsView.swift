import CaffeineKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.bedtimeMinutes) private var bedtimeMinutes = 23 * 60
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(SettingsKey.profileAge) private var profileAge = 0
    @AppStorage(SettingsKey.profileWeight) private var profileWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var pregnant = false
    @AppStorage(SettingsKey.sensitivity) private var sensitivityRaw = CaffeineSensitivity.normal.rawValue
    @AppStorage(SettingsKey.morningReminder) private var morningReminder = false
    @AppStorage(SettingsKey.morningReminderMinutes) private var morningMinutes = 7 * 60 + 30
    @AppStorage(SettingsKey.weeklyReminder) private var weeklyReminder = false
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(SettingsKey.healthSyncEnabled) private var healthSync = false
    @Environment(\.modelContext) private var context
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]
    @State private var confirmDelete = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Picker("Dil", selection: Binding(
                    get: { AppLanguage(rawValue: languageRaw) ?? .system },
                    set: { AppLanguage.apply($0); languageRaw = $0.rawValue }
                )) {
                    Text(verbatim: AppLanguage.system.nativeName).tag(AppLanguage.system)
                    Section {
                        ForEach(AppLanguage.choices) { Text(verbatim: $0.nativeName).tag($0) }
                    }
                }
            } footer: {
                Text("Uygulama hemen değişir. İzin pencereleri ve bildirimler uygulama yeniden açılınca değişir.")
            }

            Section {
                DatePicker("Genelde yatış saatin", selection: minutesBinding($bedtimeMinutes), displayedComponents: .hourAndMinute)
            } header: {
                Text("Uyku")
            } footer: {
                Text("Kafein eğrisi ve son kahve saati bu saate göre hesaplanır.")
            }

            Section {
                NavigationLink { ProfileView() } label: {
                    LabeledContent("Yaş ve kilo") {
                        if let profile {
                            Text("\(profile.age) · \(Int(profile.weightKg)) kg")
                        } else {
                            Text("Girilmedi").foregroundStyle(Theme.alert)
                        }
                    }
                }
                LabeledContent("Günlük kafein sınırın", value: limit.dailyMg.mgText)
            } header: {
                Text("Profil")
            } footer: {
                Text(LimitText.basis(limit.basis) + " " + L("Kalp rahatsızlığın varsa ya da ilaç kullanıyorsan doktoruna danış."))
            }

            Section {
                Picker("Kafein sende ne kadar sürüyor?", selection: $sensitivityRaw) {
                    Text("Kısa (yarısı ~3,5 saatte atılır)").tag(CaffeineSensitivity.fast.rawValue)
                    Text("Ortalama (~5 saat)").tag(CaffeineSensitivity.normal.rawValue)
                    Text("Uzun (~7 saat)").tag(CaffeineSensitivity.slow.rawValue)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                LabeledContent("Bu seçimle bugünkü son kahve saatin", value: lastCupPreview)
                LabeledContent("Yatarken vücudunda kalacak kafein", value: bedtimePreview)
            } header: {
                Text("Kafein sende ne kadar sürüyor?")
            } footer: {
                Text("Kafeinin vücuttan atılma hızı kişiden kişiye değişir: genetik, hamilelik, doğum kontrol hapı ve sigara bunu etkiler. Öğleden sonra içtiğin kahve gece uykunu bozuyorsa \"Uzun\"u seç. Bu seçim kafein eğrisini, yatarken kalan kafeini ve son kahve saatini değiştirir.")
            }

            Section {
                Toggle("Sabah hatırlatıcısı", isOn: $morningReminder)
                    .onChange(of: morningReminder) { _, on in Task { await updateMorning(on) } }
                if morningReminder {
                    DatePicker("Saat", selection: minutesBinding($morningMinutes), displayedComponents: .hourAndMinute)
                        .onChange(of: morningMinutes) { _, _ in Task { await updateMorning(true) } }
                }
                Toggle("Pazar akşamı haftalık özet", isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, on in Task { await updateWeekly(on) } }
            } header: {
                Text("Hatırlatıcılar")
            } footer: {
                if let message { Text(message) }
            }

            Section("Ölçüm") {
                Toggle("Her atımda titreşim", isOn: $hapticsEnabled)
                Toggle("Sabah nabzını Apple Sağlık'a kaydet", isOn: $healthSync)
                    .disabled(!HealthKitService.shared.isAvailable)
                    .onChange(of: healthSync) { _, enabled in
                        guard enabled else { return }
                        Task {
                            if !(await HealthKitService.shared.requestAuthorization()) {
                                healthSync = false
                                message = L("Sağlık izni verilmedi. Ayarlar → Sağlık → Veri Erişimi bölümünden açabilirsin.")
                            }
                        }
                    }
            }

            Section {
                NavigationLink("Nasıl çalışır?") { HowItWorksView() }
                NavigationLink("Çarpıntı rehberi") { PalpitationGuideView() }
                Link("Gizlilik politikası", destination: AppLinks.privacyPolicy)
                Link("Destek", destination: AppLinks.support)
            }

            Section {
                Button("Tüm verileri sil", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("Tüm kayıtların yalnızca bu telefonda saklanır. Hesap yok, sunucu yok, reklam yok.")
            }

            Section {
                Text("Caffein bir sağlıklı yaşam uygulamasıdır; tıbbi cihaz değildir ve teşhis ya da tedavi amacıyla kullanılmamalıdır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("Sürüm", value: BuildInfo.version)
            }
        }
        .navigationTitle("Ayarlar")
        .confirmationDialog("Tüm veriler silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Sil", role: .destructive) { DataReset.deleteAll(in: context) }
        } message: {
            Text("İçecekler, ölçümler, uyku ve gerginlik kayıtları kalıcı olarak silinir. Bu işlem geri alınamaz.")
        }
    }

    private var profile: CaffeineProfile? {
        CaffeinePreferences.profile(age: profileAge, weight: profileWeight, pregnant: pregnant)
    }

    private var limit: CaffeineLimit.Result {
        CaffeineLimit.daily(for: profile)
    }

    /// Today's caffeine status under the currently selected sensitivity,
    /// so the user sees what the choice changes.
    private var sensitivityStatus: Wellness.CaffeineStatus {
        let prefs = CaffeinePreferences(bedtimeMinutes: bedtimeMinutes,
                                        sensitivity: CaffeineSensitivity(rawValue: sensitivityRaw) ?? .normal,
                                        profile: profile)
        return Wellness.caffeineStatus(intakes, prefs: prefs)
    }

    private var lastCupPreview: String {
        guard let last = sensitivityStatus.lastCupTime else { return L("bugün için kalmadı") }
        return last < Date() ? L("geçti (\(last.clockText))") : last.clockText
    }

    private var bedtimePreview: String {
        sensitivityStatus.atBedtimeMg.mgText
    }

    private func minutesBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { DayClock.date(from: minutes.wrappedValue) },
            set: { minutes.wrappedValue = DayClock.minutes(from: $0) }
        )
    }

    private func updateMorning(_ on: Bool) async {
        ReminderService.cancelMorning()
        guard on else { return }
        if await ReminderService.requestPermission() {
            await ReminderService.scheduleMorning(minutes: morningMinutes)
        } else {
            morningReminder = false
            message = L("Bildirim izni verilmedi. Ayarlar → Bildirimler → Caffein bölümünden açabilirsin.")
        }
    }

    private func updateWeekly(_ on: Bool) async {
        ReminderService.cancelWeekly()
        guard on else { return }
        if await ReminderService.requestPermission() {
            await ReminderService.scheduleWeekly()
        } else {
            weeklyReminder = false
            message = L("Bildirim izni verilmedi. Ayarlar → Bildirimler → Caffein bölümünden açabilirsin.")
        }
    }
}

enum DataReset {
    @MainActor
    static func deleteAll(in context: ModelContext) {
        try? context.delete(model: CaffeineIntake.self)
        try? context.delete(model: PulseReading.self)
        try? context.delete(model: SleepLog.self)
        try? context.delete(model: TensionRating.self)
        try? context.save()
    }
}

struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Kafein eğrisi",
                        "İçtiğin kafein yaklaşık 45 dakikada kana karışır, sonra vücudun onu yavaş yavaş atar. Yarısının atılması ortalama 5 saat sürer, ama bu kişiye göre 2 ile 10 saat arasında değişir. Caffein her içeceği bu modele göre toplar ve gün boyu vücudunda ne kadar kafein olduğunu tahmin eder.")
                section("Son kahve saati",
                        "Yatarken vücudunda yaklaşık \(Int(CaffeineModel.sleepThresholdMg)) mg'den fazla kafein kalması derin uykuyu azaltabilir. Caffein, genelde içtiğin miktarda bir içeceği en geç ne zaman içersen yatış saatinde bu eşiğin altında kalacağını hesaplar.")
                section("Günlük sınır",
                        "Sınırın yaşına ve kilona göre hesaplanır (EFSA). Yetişkinlerde kilo başına yaklaşık 5,7 mg, en fazla 400 mg; 70 kg'lık bir yetişkin için bu yaklaşık 4 kupa filtre kahvedir. 18 yaş altında kilo başına 3 mg. Hamilelik ve emzirmede en fazla 200 mg. Sınıra yaklaştığında ve geçtiğinde Bugün ekranında grafiğin altında uyarı görürsün. Bu bir hedef değil, bir üst sınırdır.")
                section("Nabız ölçümü",
                        "Her kalp atışında parmak ucuna biraz daha kan dolar ve bu kan flaşın ışığını biraz daha emer. Kamera bu küçük renk değişimini saniyede 30 kez okur. Sinyal net değilse Caffein sayı göstermez ve tekrar ölçmeni ister.")
                section("Gerginlik göstergesi",
                        "Sabah dinlenme nabzın birkaç günde kişisel bir normal oluşturur. Bir sabah nabzın bu normalden belirgin şekilde yüksekse, bu uykusuzluk, stres, hastalık ya da geç kafeinin işareti olabilir. Caffein bunu akşam verdiğin gerginlik puanıyla birleştirir.")
                section("Kişisel çıkarımlar",
                        "En az bir haftalık kayıttan sonra Caffein kendi verilerini karşılaştırır: örneğin yatarken kafein kalan gecelerde uyku puanın düşüyor mu? Bunlar senin verindeki eğilimlerdir, kesin neden-sonuç ilişkisi değildir.")
                section("Verilerin",
                        "Her şey yalnızca bu telefonda saklanır. Kamera görüntüsü kaydedilmez; her kareden yalnızca ortalama renk değeri alınır.")
                section("Sınırlar",
                        "Caffein tıbbi bir cihaz değildir. Ritim bozukluğu gibi durumları tespit etmez. Sağlığınla ilgili bir endişen varsa doktoruna danış.")
            }
            .padding(24)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Nasıl çalışır?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(body).foregroundStyle(.secondary)
        }
    }
}
