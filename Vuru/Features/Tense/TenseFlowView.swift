import CaffeineKit
import PulseKit
import SwiftData
import SwiftUI

/// L("Gerginim"): measure, breathe slowly for two minutes, measure again.
struct TenseFlowView: View {
    enum Step: Equatable { case before, breathe, after, result }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]

    @State private var step: Step = .before
    @State private var before: PulseResult?
    @State private var after: PulseResult?
    @State private var sessionID = UUID()
    @State private var showGuide = false

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
                            withAnimation { step = .breathe }
                        },
                        onSkip: { withAnimation { step = .breathe } }
                    )
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
                    if step != .result { Button("Vazgeç") { dismiss() } }
                }
            }
            .navigationDestination(isPresented: $showGuide) { PalpitationGuideView() }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .before: L("1/3 · Ölçüm")
        case .breathe: L("2/3 · Nefes")
        case .after: L("3/3 · Tekrar ölçüm")
        case .result: L("Gerginim")
        }
    }

    private func finish() {
        if let before {
            context.insert(PulseReading(bpm: before.bpm, kind: .tenseBefore, quality: before.quality.rawValue, sessionID: sessionID))
        }
        if let after {
            context.insert(PulseReading(bpm: after.bpm, kind: .tenseAfter, quality: after.quality.rawValue, sessionID: sessionID))
        }
        withAnimation { step = .result }
    }

    private var caffeineNow: Double {
        let prefs = CaffeinePreferences.current
        return Wellness.caffeineStatus(intakes, prefs: prefs).nowMg
    }

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
                } else {
                    Text("İki dakikalık nefes tamamlandı. Kendine bu molayı verdiğin için iyi yaptın.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if showsPalpitationAdvice {
                    Button { showGuide = true } label: {
                        Label("Çarpıntı ve yüksek nabız için öneriler", systemImage: "heart.text.square.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Theme.alert.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.alert)
                }

                if caffeineNow >= 100 {
                    Text("Vücudunda şu an yaklaşık \(caffeineNow.mgText) kafein var. Bugün için bir sonraki kahveyi atlamak gerginliğine iyi gelebilir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Bitti") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
            }
            .padding(24)
        }
    }

    private var showsPalpitationAdvice: Bool {
        (before?.bpm ?? 0) >= 100 || (after?.bpm ?? 0) >= 100 || caffeineNow >= 200
    }

    private func bpmColumn(_ bpm: Int, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(String(bpm))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
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
