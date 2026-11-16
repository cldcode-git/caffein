import CaffeineKit
import Foundation

/// Turns stored records into what the screens show. Pure functions over the
/// arrays that `@Query` hands the views, so it is easy to reason about.
enum Wellness {
    struct CaffeineStatus {
        var nowMg: Double
        var todayTotalMg: Double
        var bedtime: Date
        var atBedtimeMg: Double
        /// Nil: no more caffeine today. Past date: the window has closed.
        var lastCupTime: Date?
        var typicalDoseMg: Double
        var curve: [CurvePoint]
        var dailyLimitMg: Double
        var timeBelowThreshold: Date?
    }

    static func doses(_ intakes: [CaffeineIntake]) -> [CaffeineDose] {
        intakes.map { CaffeineDose(time: $0.date, milligrams: $0.caffeineMg) }
    }

    static func todayIntakes(_ intakes: [CaffeineIntake], now: Date = Date()) -> [CaffeineIntake] {
        let start = DayClock.dayStart(for: now)
        return intakes.filter { $0.date >= start && $0.date <= now.addingTimeInterval(60) }
            .sorted { $0.date > $1.date }
    }

    /// A personal "next cup" size: the upper quartile of recent drinks, never
    /// below a small coffee (60 mg), so a habit of small teas does not push
    /// the suggested cut-off to bedtime.
    static func typicalDose(_ intakes: [CaffeineIntake], now: Date = Date()) -> Double {
        let recent = intakes.filter { $0.date > now.addingTimeInterval(-14 * 86_400) && $0.caffeineMg >= 20 }
            .map(\.caffeineMg).sorted()
        guard !recent.isEmpty else { return 80 }
        return max(60, recent[(recent.count * 3) / 4])
    }

    static func caffeineStatus(_ intakes: [CaffeineIntake], prefs: CaffeinePreferences,
                               now: Date = Date()) -> CaffeineStatus {
        let model = prefs.model
        // Yesterday's late drinks still count towards today's level.
        let relevant = doses(intakes.filter { $0.date > now.addingTimeInterval(-36 * 3600) && $0.date <= now })
        let dayStart = DayClock.dayStart(for: now)
        let bedtime = DayClock.bedtime(forDayStarting: dayStart, minutes: prefs.bedtimeMinutes)
        let typical = typicalDose(intakes, now: now)
        let todayTotal = todayIntakes(intakes, now: now).map(\.caffeineMg).reduce(0, +)

        let lastCup = model.latestIntakeTime(existing: relevant, nextDoseMg: typical,
                                             bedtime: bedtime, earliest: dayStart)
        let below = model.timeWhenBelow(CaffeineModel.sleepThresholdMg, doses: relevant, after: now)

        let curveStart = min(dayStart.addingTimeInterval(2 * 3600),
                             relevant.map(\.time).filter { $0 >= dayStart }.min() ?? now,
                             lastCup ?? .distantFuture)
        var curveEnd = max(bedtime, now).addingTimeInterval(2 * 3600)
        // With no cup left today, the chart marks when the level drops below
        // the sleep threshold; keep that moment visible (up to 12 h after bed).
        if lastCup == nil, let below, below > curveEnd {
            curveEnd = min(below.addingTimeInterval(1800), bedtime.addingTimeInterval(12 * 3600))
        }

        return CaffeineStatus(
            nowMg: model.level(relevant, at: now),
            todayTotalMg: todayTotal,
            bedtime: bedtime,
            atBedtimeMg: model.peakDuringSleep(relevant, bedtime: bedtime),
            lastCupTime: lastCup,
            typicalDoseMg: typical,
            curve: model.curve(relevant, from: curveStart, to: curveEnd, step: 900),
            dailyLimitMg: prefs.dailyLimitMg,
            timeBelowThreshold: below
        )
    }

    // MARK: - Pulse & stress

    /// Morning readings, newest first.
    static func morningReadings(_ readings: [PulseReading]) -> [PulseReading] {
        readings.filter { $0.kind == .morning }.sorted { $0.date > $1.date }
    }

    static func todaysMorningReading(_ readings: [PulseReading], now: Date = Date()) -> PulseReading? {
        let start = DayClock.dayStart(for: now)
        return morningReadings(readings).first { $0.date >= start }
    }

    /// Personal normal from earlier mornings, excluding today's.
    static func baseline(_ readings: [PulseReading], now: Date = Date()) -> HeartBaseline? {
        let start = DayClock.dayStart(for: now)
        let earlier = morningReadings(readings).filter { $0.date < start }.map { Double($0.bpm) }
        return StressIndex.baseline(morningBPMs: earlier)
    }

    static func baselineProgress(_ readings: [PulseReading], now: Date = Date()) -> Int {
        let start = DayClock.dayStart(for: now)
        return min(morningReadings(readings).filter { $0.date < start }.count, StressIndex.minimumBaselineDays)
    }

    /// The most recent tension rating from today or yesterday evening.
    static func recentTension(_ ratings: [TensionRating], now: Date = Date()) -> TensionRating? {
        let yesterday = DayClock.dayStart(for: now.addingTimeInterval(-86_400))
        return ratings.filter { $0.day >= yesterday }.max { $0.day < $1.day }
    }

    static func todaysTension(_ ratings: [TensionRating], now: Date = Date()) -> TensionRating? {
        let start = DayClock.dayStart(for: now)
        return ratings.first { $0.day == start }
    }

    static func todaysSleep(_ logs: [SleepLog], now: Date = Date()) -> SleepLog? {
        let start = DayClock.dayStart(for: now)
        return logs.filter { $0.date >= start }.max { $0.date < $1.date }
    }

    static func stress(readings: [PulseReading], ratings: [TensionRating], now: Date = Date()) -> StressAssessment? {
        StressIndex.assess(
            morningBPM: todaysMorningReading(readings, now: now).map { Double($0.bpm) },
            baseline: baseline(readings, now: now),
            tensionScore: recentTension(ratings, now: now)?.score
        )
    }

    // MARK: - Days for the weekly view

    static func daySummaries(days count: Int, intakes: [CaffeineIntake], readings: [PulseReading],
                             sleep: [SleepLog], ratings: [TensionRating], prefs: CaffeinePreferences,
                             now: Date = Date()) -> [DaySummary] {
        let model = prefs.model
        let today = DayClock.dayStart(for: now)
        let allDoses = doses(intakes)

        return (0..<count).reversed().compactMap { offset -> DaySummary? in
            guard let start = DayClock.calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let end = DayClock.nextDayStart(after: start)
            let dayIntakes = intakes.filter { $0.date >= start && $0.date < end }
            let nextMorningSleep = sleep.first { $0.date >= end && $0.date < DayClock.nextDayStart(after: end) }
            let nextMorningPulse = readings.first {
                $0.kind == .morning && $0.date >= end && $0.date < DayClock.nextDayStart(after: end)
            }
            let bedtime = nextMorningSleep?.bedtime
                ?? DayClock.bedtime(forDayStarting: start, minutes: prefs.bedtimeMinutes)
            let isPastNight = bedtime < now
            let dosesUntilBed = allDoses.filter { $0.time < bedtime }
            let sessions = Dictionary(grouping: readings.filter {
                $0.sessionID != nil && $0.date >= start && $0.date < end
            }, by: { $0.sessionID! })
            let drops: [Double] = sessions.values.compactMap { group in
                guard let before = group.first(where: { $0.kind == .tenseBefore }),
                      let after = group.first(where: { $0.kind == .tenseAfter }) else { return nil }
                return Double(before.bpm - after.bpm)
            }

            return DaySummary(
                day: start,
                caffeineMg: dayIntakes.map(\.caffeineMg).reduce(0, +),
                lastIntake: dayIntakes.map(\.date).max(),
                bedtimeLevelMg: isPastNight && !dayIntakes.isEmpty
                    ? model.peakDuringSleep(dosesUntilBed, bedtime: bedtime) : nil,
                sleepQuality: nextMorningSleep?.quality,
                sleepMinutes: nextMorningSleep?.sleepMinutes,
                nextMorningBPM: nextMorningPulse.map { Double($0.bpm) },
                tension: ratings.first { $0.day == start }?.score,
                breathingDrops: drops
            )
        }
    }
}

extension Double {
    /// Caffeine amounts are estimates; show them rounded to 5 mg.
    var mgText: String {
        "\(Int((self / 5).rounded() * 5)) mg"
    }
}

extension Date {
    var clockText: String {
        formatted(.dateTime.hour().minute().locale(AppLanguage.current.locale))
    }

    /// "23:40", or "yarın 10:09" when it falls on the next calendar day.
    func clockText(relativeTo now: Date) -> String {
        DayClock.calendar.isDate(self, inSameDayAs: now) || self < now
            ? clockText
            : L("yarın \(clockText)")
    }

    var weekdayText: String {
        formatted(.dateTime.weekday(.wide).locale(AppLanguage.current.locale))
    }
}
