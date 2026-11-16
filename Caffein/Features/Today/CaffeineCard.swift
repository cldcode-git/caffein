import CaffeineKit
import Charts
import SwiftUI

/// Caffeine in the body now and at bedtime, the curve, and under it every
/// warning: last-cup time, the age/weight-based daily limit and high levels.
struct CaffeineCard: View {
    let status: Wellness.CaffeineStatus
    let limit: CaffeineLimit.Result
    let now: Date
    let openGuide: () -> Void
    let editProfile: () -> Void

    var body: some View {
        Card(title: "Kafein", symbol: "cup.and.saucer.fill", tint: Theme.caffeine) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.nowMg.mgText)
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.caffeine)
                    Text("şu an vücudunda")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(status.atBedtimeMg.mgText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(bedtimeColor)
                    Text("yatarken (\(status.bedtime.clockText))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            chart
                .frame(height: 150)

            lastCupLine

            limitWarning

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: min(status.todayTotalMg, limit.dailyMg), total: limit.dailyMg)
                    .tint(progressTint)
                Text("Bugün \(status.todayTotalMg.mgText) / \(limit.dailyMg.mgText) günlük sınır")
                    .font(.footnote)
                    .foregroundStyle(limitStatus == .over ? Theme.alert : .secondary)
                if limit.basis == .generalReference {
                    Button(action: editProfile) {
                        Label("Yaşını ve kilonu gir, sınırı sana göre hesaplayalım", systemImage: "person.crop.circle.badge.plus")
                            .font(.footnote.weight(.medium))
                    }
                } else {
                    Button(action: editProfile) {
                        Text(LimitText.basis(limit.basis))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var limitStatus: CaffeineLimit.Status {
        CaffeineLimit.status(todayMg: status.todayTotalMg, nextDoseMg: status.typicalDoseMg, limitMg: limit.dailyMg)
    }

    private var progressTint: Color {
        switch limitStatus {
        case .over: Theme.alert
        case .approaching: Theme.caffeine
        case .below: Theme.calm
        }
    }

    private var bedtimeColor: Color {
        status.atBedtimeMg > CaffeineModel.sleepThresholdMg ? Theme.alert : Theme.sleep
    }

    private var chart: some View {
        Chart {
            ForEach(status.curve) { point in
                AreaMark(x: .value("Saat", point.time), y: .value("mg", point.milligrams))
                    .foregroundStyle(LinearGradient(colors: [Theme.caffeine.opacity(0.45), Theme.caffeine.opacity(0.05)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Saat", point.time), y: .value("mg", point.milligrams))
                    .foregroundStyle(Theme.caffeine)
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("Uyku eşiği", CaffeineModel.sleepThresholdMg))
                .foregroundStyle(Theme.sleep.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            RuleMark(x: .value("Şimdi", now))
                .foregroundStyle(Color.primary.opacity(0.35))
                .annotation(position: .top, alignment: .center) {
                    Text("şimdi").font(.caption2).foregroundStyle(.secondary)
                }
            RuleMark(x: .value("Yatış", status.bedtime))
                .foregroundStyle(Theme.sleep)
                .annotation(position: .top, alignment: .center) {
                    Image(systemName: "moon.fill").font(.caption2).foregroundStyle(Theme.sleep)
                }
            if let boundary {
                RuleMark(x: .value("Sınır saati", boundary.time))
                    .foregroundStyle(boundary.tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .annotation(position: .bottom, alignment: .center, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Label(boundary.time.clockText(relativeTo: now), systemImage: boundary.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(boundary.tint)
                            .padding(.horizontal, 4)
                            .background(Theme.card.opacity(0.9), in: Capsule())
                    }
            }
        }
        .chartYScale(domain: 0...max(120, (status.curve.map(\.milligrams).max() ?? 0) * 1.15))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .accessibilityLabel("Gün boyu kafein eğrisi")
        .accessibilityValue("Şu an \(status.nowMg.mgText), yatarken \(status.atBedtimeMg.mgText)")
    }

    /// The age/weight-based daily limit: warns when close and when passed.
    /// A high level in the body right now also gets a pointer to the guide.
    @ViewBuilder
    private var limitWarning: some View {
        let remaining = max(0, limit.dailyMg - status.todayTotalMg)
        switch limitStatus {
        case .over:
            warning(symbol: "exclamationmark.triangle.fill", tint: Theme.alert,
                    title: "Günlük sınırını geçtin: \(status.todayTotalMg.mgText) / \(limit.dailyMg.mgText)",
                    detail: "Bugün için kafeini burada bırakman iyi olur. Çarpıntı, titreme ya da huzursuzluk hissediyorsan rehbere bak.",
                    showsGuide: true)
        case .approaching:
            warning(symbol: "exclamationmark.circle.fill", tint: Theme.caffeine,
                    title: "Günlük sınırına yaklaşıyorsun: \(status.todayTotalMg.mgText) / \(limit.dailyMg.mgText)",
                    detail: "Bugün için kalan: \(remaining.mgText). Genelde içtiğin bir içecek (\(status.typicalDoseMg.mgText)) sınırı aşabilir.",
                    showsGuide: status.nowMg >= 200)
        case .below:
            if status.nowMg >= 200 {
                warning(symbol: "heart.text.square.fill", tint: Theme.alert,
                        title: "Vücudunda şu an yüksek miktarda kafein var",
                        detail: "Çarpıntı, titreme ya da huzursuzluk hissediyorsan neler yapabileceğine bak.",
                        showsGuide: true)
            }
        }
    }

    private func warning(symbol: String, tint: Color, title: LocalizedStringKey, detail: LocalizedStringKey,
                         showsGuide: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                if showsGuide {
                    Button(action: openGuide) {
                        Label("Çarpıntı rehberi", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                            .font(.footnote.weight(.semibold))
                    }
                    .tint(tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The moment that sets today's caffeine boundary, also drawn on the chart:
    /// the last-cup time, or, when no cup is left today, when the level drops
    /// below the sleep threshold.
    private struct Boundary {
        var time: Date
        var symbol: String
        var tint: Color
    }

    private var boundary: Boundary? {
        if let last = status.lastCupTime {
            return Boundary(time: last, symbol: "cup.and.saucer.fill", tint: Theme.caffeine)
        }
        if let below = status.timeBelowThreshold {
            return Boundary(time: below, symbol: "moon.zzz.fill", tint: Theme.sleep)
        }
        return nil
    }

    @ViewBuilder
    private var lastCupLine: some View {
        if let last = status.lastCupTime, last > now {
            Label {
                Text("Bugünkü son kahve saatin: **\(last.clockText)**. Sonrası uykunu etkileyebilir.")
            } icon: {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(Theme.caffeine)
            }
            .font(.subheadline)
        } else if let last = status.lastCupTime {
            Label {
                Text("Bugünün son kahve saati (**\(last.clockText)**) geçti. Canın çekerse kafeinsiz bir içecek seç.")
            } icon: {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(Theme.caffeine)
            }
            .font(.subheadline)
        } else if let below = status.timeBelowThreshold {
            Label {
                Text("Yatarken vücudunda hâlâ kafein olacak; seviyen ancak **\(below.clockText(relativeTo: now))** civarında uyku eşiğinin altına iner. Bugün için kafeini burada bırakmak uykuna iyi gelir.")
            } icon: {
                Image(systemName: "moon.zzz.fill").foregroundStyle(Theme.sleep)
            }
            .font(.subheadline)
        } else {
            Label {
                Text("Yatarken vücudunda hâlâ kafein olacak. Bugün için kafeini burada bırakmak uykuna iyi gelir.")
            } icon: {
                Image(systemName: "moon.zzz.fill").foregroundStyle(Theme.sleep)
            }
            .font(.subheadline)
        }
    }
}

struct QuickAddCard: View {
    let drinks: [Drink]
    let todayIntakes: [CaffeineIntake]
    let add: (Drink) -> Void
    let delete: (CaffeineIntake) -> Void
    let more: () -> Void

    var body: some View {
        Card(title: "Ne içtin?", symbol: "plus.circle.fill", tint: Theme.caffeine, headerAction: more) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(drinks) { drink in
                        Button { add(drink) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: drink.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Theme.caffeine)
                                Text(DrinkText.name(drink.id) ?? drink.id)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                Text(drink.caffeineMg.mgText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 92, height: 96)
                            .background(Theme.caffeine.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(DrinkText.name(drink.id) ?? drink.id) ekle, \(Int(drink.caffeineMg)) miligram")
                    }
                    Button(action: more) {
                        VStack(spacing: 6) {
                            Image(systemName: "ellipsis.circle").font(.title3)
                            Text("Diğer").font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 72, height: 96)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !todayIntakes.isEmpty {
                VStack(spacing: 0) {
                    ForEach(todayIntakes) { intake in
                        HStack {
                            Image(systemName: intake.symbol)
                                .foregroundStyle(Theme.caffeine)
                                .frame(width: 24)
                            Text(DrinkText.displayName(intake)).font(.subheadline)
                            Spacer()
                            Text(intake.caffeineMg.mgText).font(.subheadline).foregroundStyle(.secondary)
                            Text(intake.date.clockText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .contextMenu {
                            Button("Sil", systemImage: "trash", role: .destructive) { delete(intake) }
                        }
                        if intake.id != todayIntakes.last?.id { Divider() }
                    }
                }
                Text("Silmek için kayda basılı tut.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
