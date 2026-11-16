import CaffeineKit
import PulseKit
import SwiftData
import SwiftUI

/// Morning routine: 60-second resting pulse, then bedtime, wake time and
/// how the night felt.
struct MorningCheckInView: View {
    enum Step { case intro, measure, sleep, done }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PulseReading.date, order: .reverse) private var readings: [PulseReading]
    @AppStorage(SettingsKey.bedtimeMinutes) private var bedtimeMinutes = 23 * 60
    @AppStorage(SettingsKey.healthSyncEnabled) private var healthSync = false

    @State private var step: Step = .intro
    @State private var pulse: PulseResult?
    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var quality: Int?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .intro: intro
                case .measure:
                    PulseMeasurementView(
                        duration: 60,
                        instruction: L("Arka kamerayı ve flaşı parmak ucunla hafifçe ört."),
                        onResult: { result in
                            pulse = result
                            withAnimation { step = .sleep }
                        },
                        onSkip: { withAnimation { step = .sleep } }
                    )
                case .sleep: sleepQuestions
                case .done: summary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Sabah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .done { Button("Vazgeç") { dismiss() } }
                }
            }
        }
        .onAppear {
            bedtime = defaultBedtime()
            // Opened in the morning: woke up about now. Later in the day: assume 07:00.
            let now = Date()
            wakeTime = DayClock.calendar.component(.hour, from: now) < 12
                ? Self.roundedToFiveMinutes(now)
                : DayClock.date(from: 7 * 60, on: now)
        }
    }

    private var intro: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sunrise.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.sleep)
            Text("Günaydın")
                .font(.title.weight(.semibold))
            Text("Yataktan kalkmadan ya da kalktıktan hemen sonra, oturarak ölç. Kahveden önce ölçmek kişisel normalini daha doğru yapar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button("Ölçüme başla (60 sn)") { withAnimation { step = .measure } }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.sleep))
                .padding(.horizontal, 24)
            Button("Sadece uyku sorularını yanıtla") { withAnimation { step = .sleep } }
                .font(.subheadline)
                .padding(.bottom, 16)
        }
    }

    private var sleepQuestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let pulse {
                    Label("Nabzın \(pulse.bpm) BPM olarak kaydedilecek.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.calm)
                        .font(.subheadline)
                }

                VStack(spacing: 0) {
                    DatePicker("Kaçta yattın?", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .padding(.vertical, 10)
                    Divider()
                    DatePicker("Kaçta uyandın?", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .padding(.vertical, 10)
                    Divider()
                    HStack {
                        Text("Uyku süresi")
                        Spacer()
                        Text(sleepMinutes.map { durationText(minutes: $0) } ?? "–")
                            .font(.headline)
                            .foregroundStyle(sleepMinutes == nil ? Theme.alert : Theme.sleep)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if sleepMinutes == nil {
                    Text("Yatış ve uyanış saatini kontrol et; uyku süresi 1 ile 16 saat arasında olmalı.")
                        .font(.footnote)
                        .foregroundStyle(Theme.alert)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nasıl uyudun?").font(.headline)
                    VStack(spacing: 8) {
                        ForEach((1...5).reversed(), id: \.self) { value in
                            ChoiceChip(title: SleepQuality.title(value), isSelected: quality == value, tint: Theme.sleep) {
                                quality = value
                            }
                        }
                    }
                }
                Button("Kaydet") { save() }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.sleep))
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
            }
            .padding(24)
        }
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.calm)
            Text("Sabah kaydın tamam").font(.title2.weight(.semibold))
            if let minutes = sleepMinutes {
                Text("Bu gece \(durationText(minutes: minutes)) uyudun.")
                    .foregroundStyle(.secondary)
            }
            if let pulse {
                Text(baselineSentence(bpm: pulse.bpm))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button("Bitti") { dismiss() }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.sleep))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Times

    /// Bedtime placed on last night: evening times on yesterday's date,
    /// times after midnight on today's.
    private var actualBedtime: Date {
        let yesterday = DayClock.calendar.date(byAdding: .day, value: -1, to: DayClock.dayStart(for: Date())) ?? Date()
        return DayClock.bedtime(forDayStarting: yesterday, minutes: DayClock.minutes(from: bedtime))
    }

    /// Wake time placed on the morning after `actualBedtime`.
    private var actualWakeTime: Date {
        let minutes = DayClock.minutes(from: wakeTime)
        var wake = DayClock.date(from: minutes, on: actualBedtime)
        if wake <= actualBedtime { wake = DayClock.calendar.date(byAdding: .day, value: 1, to: wake) ?? wake }
        return wake
    }

    private var sleepMinutes: Double? {
        let minutes = actualWakeTime.timeIntervalSince(actualBedtime) / 60
        return (60...(16 * 60)).contains(minutes) ? minutes : nil
    }

    private var canSave: Bool { quality != nil && sleepMinutes != nil }

    private static func roundedToFiveMinutes(_ date: Date) -> Date {
        let minutes = DayClock.minutes(from: date)
        return DayClock.date(from: (minutes / 5) * 5, on: date)
    }

    private func baselineSentence(bpm: Int) -> String {
        guard let baseline = Wellness.baseline(readings) else {
            let have = min(Wellness.baselineProgress(readings) + 1, StressIndex.minimumBaselineDays)
            return L("Dinlenme nabzın \(bpm). Kişisel normalin \(StressIndex.minimumBaselineDays) sabah ölçümüyle oluşur; şu an \(have) ölçümün var.")
        }
        let normal = Int(baseline.median)
        let d = Int((Double(bpm) - baseline.median).rounded())
        if abs(d) <= 2 { return L("Dinlenme nabzın \(bpm), normalinle (\(normal)) aynı düzeyde.") }
        if d > 0 {
            return L("Dinlenme nabzın \(bpm), normalinden \(d) atım yüksek. Uykusuzluk, stres, hastalık ya da dünkü geç kafein bunu etkileyebilir.")
        }
        return L("Dinlenme nabzın \(bpm), normalinden \(-d) atım düşük.")
    }

    private func defaultBedtime() -> Date {
        DayClock.date(from: bedtimeMinutes)
    }

    private func save() {
        guard let quality, sleepMinutes != nil else { return }
        let now = Date()
        context.insert(SleepLog(date: now, bedtime: actualBedtime, wakeTime: actualWakeTime, quality: quality))

        if let pulse {
            context.insert(PulseReading(date: now, bpm: pulse.bpm, kind: .morning, quality: pulse.quality.rawValue))
            if healthSync, HealthKitService.shared.canWrite {
                Task { try? await HealthKitService.shared.save(bpm: pulse.bpm, at: now) }
            }
        }
        withAnimation { step = .done }
    }
}
