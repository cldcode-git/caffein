import CaffeineKit
import Charts
import SwiftData
import SwiftUI

struct WeeklyView: View {
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]
    @Query(sort: \PulseReading.date, order: .reverse) private var readings: [PulseReading]
    @Query(sort: \SleepLog.date, order: .reverse) private var sleepLogs: [SleepLog]
    @Query(sort: \TensionRating.day, order: .reverse) private var ratings: [TensionRating]
    @AppStorage(SettingsKey.profileAge) private var profileAge = 0
    @AppStorage(SettingsKey.profileWeight) private var profileWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var pregnant = false
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        let prefs = CaffeinePreferences.current
        let dailyLimit = prefs.dailyLimitMg
        let month = Wellness.daySummaries(days: 28, intakes: intakes, readings: readings,
                                          sleep: sleepLogs, ratings: ratings, prefs: prefs)
        let week = Array(month.suffix(7))
        let summary = WeeklySummary.make(week, dailyLimitMg: dailyLimit)
        let insights = InsightEngine.insights(month)
        let baseline = Wellness.baseline(readings)
        let loggedDays = month.filter { $0.caffeineMg > 0 || $0.sleepQuality != nil || $0.tension != nil }.count

        ScrollView {
            VStack(spacing: 16) {
                SummaryCard(summary: summary, baseline: baseline)
                    .overlay(alignment: .topTrailing) {
                        ShareSummaryButton(summary: summary, baseline: baseline)
                            .padding(14)
                    }

                Card(title: "Günlük kafein", symbol: "chart.bar.fill", tint: Theme.caffeine) {
                    Chart {
                        ForEach(week, id: \.day) { day in
                            BarMark(x: .value("Gün", day.day, unit: .day), y: .value("mg", day.caffeineMg))
                                .foregroundStyle(day.caffeineMg > dailyLimit ? Theme.alert : Theme.caffeine)
                                .cornerRadius(6)
                        }
                        RuleMark(y: .value("Sınır", dailyLimit))
                            .foregroundStyle(Theme.alert.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) {
                            AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        }
                    }
                    .frame(height: 140)
                }

                if week.contains(where: { $0.sleepQuality != nil }) {
                    Card(title: "Uyku ve yatarkenki kafein", symbol: "moon.zzz.fill", tint: Theme.sleep) {
                        Chart {
                            ForEach(week.filter { $0.sleepMinutes != nil }, id: \.day) { day in
                                BarMark(x: .value("Gün", day.day, unit: .day), y: .value("sa", (day.sleepMinutes ?? 0) / 60))
                                    .foregroundStyle((day.bedtimeLevelMg ?? 0) > CaffeineModel.sleepThresholdMg
                                                     ? Theme.caffeine : Theme.sleep)
                                    .cornerRadius(6)
                            }
                            if let avg = summary.averageSleepMinutes {
                                RuleMark(y: .value("Ortalama", avg / 60))
                                    .foregroundStyle(Theme.sleep.opacity(0.6))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) {
                                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                                AxisGridLine()
                                AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0) sa") }
                            }
                        }
                        .frame(height: 130)
                        HStack(spacing: 14) {
                            legend(Theme.sleep, "Yatarken az kafein")
                            legend(Theme.caffeine, "Yatarken kafein vardı")
                        }

                        ForEach(week.filter { $0.sleepQuality != nil }, id: \.day) { day in
                            HStack {
                                Text(day.day.weekdayText)
                                    .font(.subheadline)
                                Spacer()
                                if let level = day.bedtimeLevelMg {
                                    Text(level.mgText)
                                        .font(.caption)
                                        .foregroundStyle(level > CaffeineModel.sleepThresholdMg ? Theme.alert : .secondary)
                                }
                                Text(day.sleepMinutes.map { durationText(minutes: $0) } ?? "–")
                                    .font(.subheadline.monospacedDigit())
                                    .frame(width: 80, alignment: .trailing)
                                Text(SleepQuality.title(day.sleepQuality ?? 3))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.sleep)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: 84, alignment: .trailing)
                            }
                        }
                    }
                }

                insightsSection(insights, loggedDays: loggedDays)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Haftam")
    }

    private func legend(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func insightsSection(_ insights: [Insight], loggedDays: Int) -> some View {
        Card(title: "Sana özel çıkarımlar", symbol: "sparkles", tint: Theme.calm) {
            if insights.isEmpty {
                Text("Kişisel çıkarımlar için en az \(InsightEngine.minimumDays) günlük kayıt gerekiyor. Şu an \(min(loggedDays, InsightEngine.minimumDays)) gün var.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(min(loggedDays, InsightEngine.minimumDays)), total: Double(InsightEngine.minimumDays))
                    .tint(Theme.calm)
            } else {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbol(insight))
                            .foregroundStyle(color(insight.kind))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(InsightText.title(insight)).font(.subheadline.weight(.semibold))
                            Text(InsightText.detail(insight)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Text("Bunlar son 4 haftadaki kendi kayıtlarındaki eğilimler; neden-sonuç ilişkisi kanıtlamaz.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func symbol(_ insight: Insight) -> String {
        switch insight.kind {
        case .sleep: "moon.zzz.fill"
        case .heart: "heart.fill"
        case .tension: "waveform.path.ecg"
        case .breathing: "wind"
        case .habit: "clock.fill"
        }
    }

    private func color(_ kind: Insight.Kind) -> Color {
        switch kind {
        case .sleep: Theme.sleep
        case .heart: Theme.alert
        case .tension, .breathing: Theme.calm
        case .habit: Theme.caffeine
        }
    }
}

/// The weekly summary card; also rendered to an image for sharing.
struct SummaryCard: View {
    let summary: WeeklySummary
    let baseline: HeartBaseline?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Son 7 gün").font(.headline)
                Text("\(summary.loggedDays) gün kayıt").font(.caption).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    stat(summary.averageDailyMg.mgText, "günlük ortalama kafein", Theme.caffeine)
                    stat("\(summary.daysOverLimit)", "sınırı aşan gün", summary.daysOverLimit > 0 ? Theme.alert : Theme.calm)
                }
                GridRow {
                    stat(summary.averageSleepMinutes.map { durationText(minutes: $0) } ?? "–",
                         "ortalama uyku süresi", Theme.sleep)
                    stat(summary.averageSleepQuality.map { SleepQuality.title(Int($0.rounded())) } ?? "–",
                         "ortalama uyku kalitesi", Theme.sleep)
                }
                GridRow {
                    stat(summary.averageMorningBPM.map { "\(Int($0.rounded())) BPM" } ?? "–",
                         baseline == nil ? "sabah nabzı" : "sabah nabzı · normalin \(Int(baseline!.median))", Theme.alert)
                    stat(summary.averageTension.map { "\($0.oneDecimal) / 5" } ?? "–", "ortalama gerginlik", Theme.calm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func stat(_ value: String, _ caption: LocalizedStringKey, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShareSummaryButton: View {
    let summary: WeeklySummary
    let baseline: HeartBaseline?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    var body: some View {
        if let image = render() {
            ShareLink(item: image, preview: SharePreview(L("Haftalık özet"), image: image)) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Özet kartını paylaş")
        }
    }

    @MainActor
    private func render() -> Image? {
        let card = SummaryCard(summary: summary, baseline: baseline)
            .frame(width: 360)
            .padding(16)
            .background(Theme.canvas)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, locale)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
