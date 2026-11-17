import CaffeineKit
import PulseKit
import SwiftData
import SwiftUI

/// L("Gerginim"): measure, show the result against the person's own
/// reference, and offer two minutes of slow breathing when the pulse is
/// high for them; then measure again.
struct TenseFlowView: View {
    enum Step: Equatable { case before, firstResult, breathe, after, result }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]

    // Read live so finishing the profile from here updates the assessment.
    @AppStorage(SettingsKey.profileAge) private var profileAge = 0
    @AppStorage(SettingsKey.profileWeight) private var profileWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var pregnant = false
    @AppStorage(SettingsKey.sex) private var sexRaw = BiologicalSex.unspecified.rawValue

    @State private var step: Step = .before
    @State private var before: PulseResult?
    @State private var after: PulseResult?
    @State private var sessionID = UUID()
    @State private var showGuide = false
    @State private var showProfile = false

    private var sex: BiologicalSex { BiologicalSex(rawValue: sexRaw) ?? .unspecified }

    private var reference: PulseReference {
        RestingPulse.reference(for: CaffeinePreferences.profile(age: profileAge, weight: profileWeight,
                                                                pregnant: pregnant, sex: sex))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .before:
                    PulseMeasurementView(
                        duration: 30,
                        instruction: L("Önce şu anki nabzına bakalım. Parmağını kameraya hafifçe koy."),
                        onResult: { r in
                            before = r
                            withAnimation { step = .firstResult }
                        },
                        // Without a number we can't judge; the user asked
                        // for help, so go on to the breathing.
                        onSkip: { withAnimation { step = .breathe } }
                    )
                case .firstResult:
                    firstResult
                case .breathe:
                    BreathingView(duration: 120) { withAnimation { step = .after } }
                case .after:
                    PulseMeasurementView(
                        duration: 30,
                        instruction: L("Şimdi tekrar ölçelim. Parmağını kameraya hafifçe koy."),
                        onResult: { r in
                            after = r
                            finish()
                        },
                        onSkip: { finish() }
                    )
                case .result:
                    result
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .result && step != .firstResult { Button("Vazgeç") { dismiss() } }
                }
            }
            .navigationDestination(isPresented: $showGuide) { PalpitationGuideView() }
            .navigationDestination(isPresented: $showProfile) { ProfileView() }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .before: L("1/3 · Ölçüm")
        case .firstResult: L("Gerginim")
        case .breathe: L("2/3 · Nefes")
        case .after: L("3/3 · Tekrar ölçüm")
        case .result: L("Gerginim")
        }
    }

    // MARK: - Saving

    private func saveReadings() {
        if let before {
            context.insert(PulseReading(bpm: before.bpm, kind: .tenseBefore, quality: before.quality.rawValue, sessionID: sessionID))
        }
        if let after {
            context.insert(PulseReading(bpm: after.bpm, kind: .tenseAfter, quality: after.quality.rawValue, sessionID: sessionID))
        }
    }

    private func finish() {
        saveReadings()
        withAnimation { step = .result }
    }

    /// Done right after the first measurement, without breathing.
    private func finishEarly() {
        saveReadings()
        dismiss()
    }

    private var caffeineNow: Double {
        Wellness.caffeineStatus(intakes, prefs: CaffeinePreferences.current).nowMg
    }

    // MARK: - First result

    private var firstResult: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let bpm = before?.bpm {
                    let level = RestingPulse.level(bpm: bpm, reference: reference)
                    PulseResultHeader(bpm: bpm, level: level)
                    PulseLevelGauge(bpm: bpm, reference: reference)
                    referenceNote

                    Text(PulseLevelText.advice(level))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if level != .normal && caffeineNow >= 100 {
                        caffeineNote
                    }
                    if level == .high {
                        guideButton
                    }

                    if level == .normal {
                        Button("Bitti", action: finishEarly)
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
                        Button("Yine de nefes egzersizi yap") { withAnimation { step = .breathe } }
                            .font(.subheadline.weight(.semibold))
                            .tint(Theme.calm)
                    } else {
                        Button("2 dakikalık nefes egzersizine başla") { withAnimation { step = .breathe } }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
                        Button("Şimdi değil", action: finishEarly)
                            .font(.subheadline.weight(.semibold))
                            .tint(.secondary)
                    }
                }
            }
            .padding(24)
        }
    }

    /// What "normal" means for this person, and what it is based on.
    private var referenceNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sana göre dinlenirken beklenen nabız yaklaşık \(reference.typicalBPM) atım/dk. \(reference.elevatedFromBPM) ve üzeri biraz yüksek, \(reference.highFromBPM) ve üzeri yüksek sayılır.")
                .font(.subheadline)
            if reference.isPersonal {
                Text(sex == .unspecified
                     ? L("Yaşına ve kilona göre, nüfus verilerinden hesaplanır. Cinsiyetini de girersen değerlendirme sana daha uygun olur. Tıbbi bir değerlendirme değildir.")
                     : L("Yaşına, kilona ve cinsiyetine göre, nüfus verilerinden hesaplanır. Tıbbi bir değerlendirme değildir."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Bu, yetişkinler için genel bir değer. Yaşını, kilonu ve cinsiyetini girersen değerlendirme sana göre yapılır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !reference.isPersonal || sex == .unspecified {
                Button("Profilini tamamla") { showProfile = true }
                    .font(.footnote.weight(.semibold))
                    .tint(Theme.caffeine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var caffeineNote: some View {
        Text("Vücudunda şu an yaklaşık \(caffeineNow.mgText) kafein var. Bugün için bir sonraki kahveyi atlamak gerginliğine iyi gelebilir.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var guideButton: some View {
        Button { showGuide = true } label: {
            Label("Çarpıntı ve yüksek nabız için öneriler", systemImage: "heart.text.square.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.alert.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.alert)
    }

    // MARK: - Result after breathing

    private var result: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.calm)
                    .padding(.top, 24)

                if let b = before?.bpm, let a = after?.bpm {
                    HStack(spacing: 24) {
                        bpmColumn(b, caption: "önce")
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        bpmColumn(a, caption: "sonra")
                    }
                    Text(changeSentence(before: b, after: a))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else if let a = after?.bpm {
                    PulseResultHeader(bpm: a, level: RestingPulse.level(bpm: a, reference: reference))
                } else {
                    Text("İki dakikalık nefes tamamlandı. Kendine bu molayı verdiğin için iyi yaptın.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if let a = after?.bpm {
                    PulseLevelGauge(bpm: a, reference: reference)
                }

                if showsPalpitationAdvice {
                    guideButton
                }

                if caffeineNow >= 100 {
                    caffeineNote
                }

                Button("Bitti") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
            }
            .padding(24)
        }
    }

    private var showsPalpitationAdvice: Bool {
        let afterHigh = after.map { RestingPulse.level(bpm: $0.bpm, reference: reference) == .high } ?? false
        let beforeHighNoAfter = after == nil
            && before.map { RestingPulse.level(bpm: $0.bpm, reference: reference) == .high } == true
        return afterHigh || beforeHighNoAfter || caffeineNow >= 200
    }

    private func bpmColumn(_ bpm: Int, caption: LocalizedStringKey) -> some View {
        let level = RestingPulse.level(bpm: bpm, reference: reference)
        return VStack(spacing: 4) {
            Text(String(bpm))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(PulseLevelText.title(level))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseLevelText.color(level))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func changeSentence(before: Int, after: Int) -> String {
        let d = before - after
        if d >= 3 { return L("Nabzın \(d) atım yavaşladı. Yavaş nefes, sinir sistemini sakinleştirmenin en hızlı yollarından biri.") }
        if d <= -3 { return L("Nabzın \(-d) atım yükseldi. Bazen ölçüm anı da heyecan yaratır; birkaç dakika sonra tekrar deneyebilirsin.") }
        return L("Nabzın hemen hemen aynı kaldı. Hissettiğin rahatlama da önemli; sayı her zaman değişmeyebilir.")
    }
}

// MARK: - Result pieces

enum PulseLevelText {
    static func title(_ level: PulseLevel) -> String {
        switch level {
        case .normal: L("Normal")
        case .elevated: L("Biraz yüksek")
        case .high: L("Yüksek")
        }
    }

    static func advice(_ level: PulseLevel) -> String {
        switch level {
        case .normal:
            L("Nabzın senin için normal aralıkta. Gerginlik her zaman nabza yansımaz; istersen yine de nefes egzersizi yapabilirsin.")
        case .elevated:
            L("Nabzın senin için biraz yüksek. 2 dakikalık yavaş nefes nabzını düşürmeye yardımcı olabilir.")
        case .high:
            L("Nabzın senin için yüksek. Otur, omuzlarını bırak ve 2 dakika yavaş nefes alalım.")
        }
    }

    static func color(_ level: PulseLevel) -> Color {
        switch level {
        case .normal: Theme.calm
        case .elevated: Theme.caffeine
        case .high: Theme.alert
        }
    }

    static func symbol(_ level: PulseLevel) -> String {
        switch level {
        case .normal: "checkmark.circle.fill"
        case .elevated: "arrow.up.circle.fill"
        case .high: "exclamationmark.circle.fill"
        }
    }
}

/// The measured pulse, large, with its level for this person.
struct PulseResultHeader: View {
    let bpm: Int
    let level: PulseLevel

    var body: some View {
        VStack(spacing: 6) {
            Text("Nabzın")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(bpm))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("atım/dk")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Label(PulseLevelText.title(level), systemImage: PulseLevelText.symbol(level))
                .font(.headline)
                .foregroundStyle(PulseLevelText.color(level))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(PulseLevelText.color(level).opacity(0.14), in: Capsule())
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

/// A bar from 40 to 140 bpm split into this person's normal, a-bit-high
/// and high zones, with a marker at the measured value.
struct PulseLevelGauge: View {
    let bpm: Int
    let reference: PulseReference

    private let lower = 40.0
    private let upper = 140.0

    private func fraction(_ value: Int) -> CGFloat {
        CGFloat((min(max(Double(value), lower), upper) - lower) / (upper - lower))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let elevatedX = w * fraction(reference.elevatedFromBPM)
                let highX = w * fraction(reference.highFromBPM)
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Theme.calm.frame(width: max(0, elevatedX - 1))
                        Theme.caffeine.frame(width: max(0, highX - elevatedX - 2))
                        Theme.alert
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    .opacity(0.85)

                    Circle()
                        .fill(Theme.card)
                        .overlay(Circle().stroke(PulseLevelText.color(RestingPulse.level(bpm: bpm, reference: reference)), lineWidth: 3))
                        .frame(width: 18, height: 18)
                        .offset(x: min(max(w * fraction(bpm) - 9, 0), w - 18))
                }
                .frame(height: 24)
            }
            .frame(height: 24)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    tick(reference.elevatedFromBPM, at: w * fraction(reference.elevatedFromBPM))
                    tick(reference.highFromBPM, at: w * fraction(reference.highFromBPM))
                }
            }
            .frame(height: 16)
        }
        // A number line reads left to right in every language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func tick(_ value: Int, at x: CGFloat) -> some View {
        Text(verbatim: String(value))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize()
            .frame(width: 32)
            .offset(x: x - 16)
    }
}

/// Paced breathing: 4 seconds in, 6 seconds out. Longer exhales slow the heart.
struct BreathingView: View {
    let duration: TimeInterval
    let onFinish: () -> Void

    @State private var start = Date()
    @State private var finished = false
    @State private var lastPhaseIsInhale: Bool?
    private let inhale: TimeInterval = 4
    private let exhale: TimeInterval = 6

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let cycle = elapsed.truncatingRemainder(dividingBy: inhale + exhale)
            let isInhale = cycle < inhale
            let progress = isInhale ? cycle / inhale : 1 - (cycle - inhale) / exhale
            let remaining = max(0, Int((duration - elapsed).rounded(.up)))

            VStack(spacing: 32) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Theme.calm.opacity(0.12))
                        .frame(width: 260, height: 260)
                    Circle()
                        .fill(Theme.calm.opacity(0.35))
                        .frame(width: 120 + 140 * eased(progress), height: 120 + 140 * eased(progress))
                    (isInhale ? Text("Nefes al") : Text("Yavaşça ver"))
                        .font(.title3.weight(.semibold))
                }
                Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Burnundan 4 saniye al, ağzından 6 saniyede ver. Omuzlarını bırak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button("Atla") { complete() }
                    .padding(.bottom, 16)
            }
            .onChange(of: isInhale) { _, inhaleNow in
                UIImpactFeedbackGenerator(style: inhaleNow ? .soft : .light).impactOccurred(intensity: 0.5)
            }
            .onChange(of: remaining) { _, value in
                if value == 0 { complete() }
            }
        }
        .onAppear {
            start = Date()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .accessibilityElement(children: .combine)
    }

    private func eased(_ x: Double) -> Double {
        0.5 - 0.5 * cos(.pi * min(max(x, 0), 1))
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}
