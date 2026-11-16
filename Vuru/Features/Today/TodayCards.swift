import CaffeineKit
import SwiftUI

struct MorningCard: View {
    let reading: PulseReading?
    let sleep: SleepLog?
    let baseline: HeartBaseline?
    let start: () -> Void

    var body: some View {
        Card(title: "Sabah", symbol: "sunrise.fill", tint: Theme.sleep) {
            if reading == nil && sleep == nil {
                Text("60 saniyelik dinlenme nabzı ve kısa bir uyku kaydı. Kişisel normalini bu ölçümler oluşturur.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Sabah ölçümünü yap", action: start)
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.sleep))
            } else {
                HStack(alignment: .top, spacing: 20) {
                    stat(value: reading.map { "\($0.bpm)" } ?? "–", unit: "BPM", caption: deviationText)
                    if let sleep {
                        stat(value: sleep.sleepMinutes.map { durationText(minutes: $0) } ?? "–", unit: nil,
                             caption: L("\(sleep.bedtime.clockText) – \(sleep.wakeTime?.clockText ?? "?")"))
                        stat(value: SleepQuality.title(sleep.quality), unit: nil, caption: L("uyku kalitesi"))
                    }
                }
                if reading == nil {
                    Button("Nabzı da ölç", action: start).font(.subheadline)
                }
            }
        }
    }

    private var deviationText: String {
        guard let reading else { return L("ölçülmedi") }
        guard let baseline else { return L("normalin oluşuyor") }
        let d = Int((Double(reading.bpm) - baseline.median).rounded())
        if abs(d) <= 2 { return L("normalinde (\(Int(baseline.median)))") }
        return d > 0 ? L("normalinden \(d) yüksek") : L("normalinden \(-d) düşük")
    }

    private func stat(value: String, unit: String?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title3.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
            Text(caption).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct StressCard: View {
    let assessment: StressAssessment?
    let baselineProgress: Int
    let tense: () -> Void

    var body: some View {
        Card(title: "Gerginlik", symbol: "waveform.path.ecg", tint: Theme.calm) {
            if let assessment {
                HStack(spacing: 14) {
                    Gauge(value: assessment.score) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color(assessment.level))
                    .scaleEffect(0.9)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(StressText.title(assessment.level))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(color(assessment.level))
                        Text(explanation(assessment))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Sabah ölçümü ve akşam puanıyla burada günlük gerginlik göstergen oluşacak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if baselineProgress < StressIndex.minimumBaselineDays {
                Text("Kişisel nabız normalin: \(baselineProgress)/\(StressIndex.minimumBaselineDays) sabah ölçümü")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(action: tense) {
                Label("Gerginim", systemImage: "wind")
            }
            .buttonStyle(PrimaryButtonStyle(tint: Theme.calm))
            Text("Nabzını ölç, 2 dakika birlikte nefes alalım, sonra tekrar ölç.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func color(_ level: StressLevel) -> Color {
        switch level {
        case .low: Theme.calm
        case .moderate: Theme.caffeine
        case .high: Theme.alert
        }
    }

    private func explanation(_ a: StressAssessment) -> String {
        var parts: [String] = []
        if let d = a.heartRateDeviation {
            let v = Int(d.rounded())
            parts.append(v == 0 ? L("Sabah nabzın normalinde") :
                         (v > 0 ? L("Sabah nabzın normalinden \(v) yüksek") : L("Sabah nabzın normalinden \(-v) düşük")))
        }
        if let t = a.tensionScore {
            parts.append(L("son gerginlik puanın \(t)/5"))
        }
        return parts.joined(separator: ", ") + "."
    }
}

struct EveningCard: View {
    let score: Int?
    let rate: (Int) -> Void

    var body: some View {
        Card(title: "Akşam", symbol: "moon.stars.fill", tint: Theme.sleep) {
            Text("Bugün ne kadar gergindin?")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    ChoiceChip(title: "\(value)", isSelected: score == value, tint: Theme.sleep) {
                        rate(value)
                    }
                    .accessibilityLabel("\(value), \(TensionScale.title(value))")
                }
            }
            HStack {
                Text("1 · Çok sakin")
                Spacer()
                Text("5 · Çok gergin")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

/// Daily drinking-water suggestion: body weight plus a little extra for
/// today's caffeine. Water doesn't speed up caffeine clearance; it only
/// offsets caffeine's mild diuretic effect.
struct WaterCard: View {
    let target: WaterGuide.Target
    let hasWeight: Bool

    var body: some View {
        Card(title: "Su", symbol: "drop.fill", tint: Theme.sleep) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(liters(target.totalMl))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.sleep)
                Text("bugün önerilen · yaklaşık \(target.glasses) bardak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                row(hasWeight ? L("Kilona göre günlük ihtiyaç") : L("Günlük ihtiyaç (70 kg varsayıldı)"), target.baseMl)
                row(L("Bugünkü kafein için ek"), target.caffeineExtraMl)
            }
            .font(.footnote)
            Text("Su kafeini vücudundan daha hızlı atmaz; kafeini karaciğer kendi hızında parçalar. Ek su, kafeinin hafif idrar söktürücü etkisini dengeler.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ ml: Double) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: "\(Int(ml)) ml").monospacedDigit()
        }
    }

    private func liters(_ ml: Double) -> String {
        (ml / 1000).formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.current.locale)) + " L"
    }
}
