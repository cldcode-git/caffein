import Foundation

/// Everything known about one day, as the insight engine sees it.
public struct DaySummary: Equatable, Sendable {
    public var day: Date
    public var caffeineMg: Double
    public var lastIntake: Date?
    /// Highest caffeine level in the first hours of that night's sleep.
    public var bedtimeLevelMg: Double?
    /// Sleep rating given the next morning for this night (1–5).
    public var sleepQuality: Int?
    /// How long the user slept that night, from bedtime and wake time.
    public var sleepMinutes: Double?
    /// Resting heart rate measured the next morning.
    public var nextMorningBPM: Double?
    /// The user's tension rating for this day (1–5).
    public var tension: Int?
    /// Heart-rate drop across each breathing session that day.
    public var breathingDrops: [Double]

    public init(day: Date, caffeineMg: Double = 0, lastIntake: Date? = nil, bedtimeLevelMg: Double? = nil,
                sleepQuality: Int? = nil, sleepMinutes: Double? = nil, nextMorningBPM: Double? = nil,
                tension: Int? = nil, breathingDrops: [Double] = []) {
        self.day = day
        self.caffeineMg = caffeineMg
        self.lastIntake = lastIntake
        self.bedtimeLevelMg = bedtimeLevelMg
        self.sleepQuality = sleepQuality
        self.sleepMinutes = sleepMinutes
        self.nextMorningBPM = nextMorningBPM
        self.tension = tension
        self.breathingDrops = breathingDrops
    }

    var hasAnyData: Bool {
        caffeineMg > 0 || sleepQuality != nil || sleepMinutes != nil || nextMorningBPM != nil || tension != nil
    }
}

public struct WeeklySummary: Equatable, Sendable {
    public var loggedDays: Int
    public var totalMg: Double
    public var averageDailyMg: Double
    public var daysOverLimit: Int
    public var lateNights: Int
    public var averageSleepQuality: Double?
    public var averageSleepMinutes: Double?
    public var averageMorningBPM: Double?
    public var averageTension: Double?

    public static func make(_ days: [DaySummary], dailyLimitMg: Double) -> WeeklySummary {
        let logged = days.filter(\.hasAnyData)
        let total = days.map(\.caffeineMg).reduce(0, +)
        return WeeklySummary(
            loggedDays: logged.count,
            totalMg: total,
            averageDailyMg: logged.isEmpty ? 0 : total / Double(logged.count),
            daysOverLimit: days.filter { $0.caffeineMg > dailyLimitMg }.count,
            lateNights: days.filter { ($0.bedtimeLevelMg ?? 0) > CaffeineModel.sleepThresholdMg }.count,
            averageSleepQuality: mean(days.compactMap { $0.sleepQuality.map(Double.init) }),
            averageSleepMinutes: mean(days.compactMap(\.sleepMinutes)),
            averageMorningBPM: mean(days.compactMap(\.nextMorningBPM)),
            averageTension: mean(days.compactMap { $0.tension.map(Double.init) })
        )
    }
}

/// A finding in the user's own data. The app turns it into text.
public enum Insight: Equatable, Sendable, Identifiable {
    case lateCaffeineHurtsSleep(nights: Int, qualityDrop: Double)
    case sleepResilient
    case lateCaffeineShortensSleep(nights: Int, minutesLost: Double)
    case heavyDaysRaiseMorningHR(thresholdMg: Double, bpmIncrease: Double)
    case caffeineRaisesTension(thresholdMg: Double, increase: Double)
    case caffeineNotLinkedToTension
    case breathingHelps(sessions: Int, bpmDrop: Double)
    case breathingNeutral
    case lateNights(late: Int, total: Int)
    case balancedTiming

    public enum Kind: String, Sendable { case sleep, heart, tension, breathing, habit }

    public var id: String {
        switch self {
        case .lateCaffeineHurtsSleep, .sleepResilient: "sleepQuality"
        case .lateCaffeineShortensSleep: "sleepDuration"
        case .heavyDaysRaiseMorningHR: "heart"
        case .caffeineRaisesTension, .caffeineNotLinkedToTension: "tension"
        case .breathingHelps, .breathingNeutral: "breathing"
        case .lateNights, .balancedTiming: "habit"
        }
    }

    public var kind: Kind {
        switch self {
        case .lateCaffeineHurtsSleep, .sleepResilient, .lateCaffeineShortensSleep: .sleep
        case .heavyDaysRaiseMorningHR: .heart
        case .caffeineRaisesTension, .caffeineNotLinkedToTension: .tension
        case .breathingHelps, .breathingNeutral: .breathing
        case .lateNights, .balancedTiming: .habit
        }
    }
}

/// Simple, explainable comparisons within the user's own data. Each insight
/// needs a minimum number of days on both sides before it is shown.
public enum InsightEngine {
    public static let minimumDays = 7
    static let minimumPerGroup = 3

    public static func insights(_ days: [DaySummary]) -> [Insight] {
        guard days.filter(\.hasAnyData).count >= minimumDays else { return [] }
        return [sleepQualityInsight(days), sleepDurationInsight(days), heartInsight(days),
         tensionInsight(days), breathingInsight(days), habitInsight(days)].compactMap { $0 }
    }

    private static func lateSplit(_ days: [DaySummary]) -> (late: [DaySummary], early: [DaySummary]) {
        let known = days.filter { $0.bedtimeLevelMg != nil }
        return (known.filter { $0.bedtimeLevelMg! > CaffeineModel.sleepThresholdMg },
                known.filter { $0.bedtimeLevelMg! <= CaffeineModel.sleepThresholdMg })
    }

    static func sleepQualityInsight(_ days: [DaySummary]) -> Insight? {
        let split = lateSplit(days.filter { $0.sleepQuality != nil })
        let high = split.late.compactMap { $0.sleepQuality.map(Double.init) }
        let low = split.early.compactMap { $0.sleepQuality.map(Double.init) }
        guard high.count >= minimumPerGroup, low.count >= minimumPerGroup,
              let mHigh = mean(high), let mLow = mean(low) else { return nil }
        let diff = mLow - mHigh
        return diff >= 0.5 ? .lateCaffeineHurtsSleep(nights: high.count, qualityDrop: diff) : .sleepResilient
    }

    static func sleepDurationInsight(_ days: [DaySummary]) -> Insight? {
        let split = lateSplit(days.filter { $0.sleepMinutes != nil })
        let late = split.late.compactMap(\.sleepMinutes)
        let early = split.early.compactMap(\.sleepMinutes)
        guard late.count >= minimumPerGroup, early.count >= minimumPerGroup,
              let mLate = mean(late), let mEarly = mean(early), mEarly - mLate >= 20 else { return nil }
        return .lateCaffeineShortensSleep(nights: late.count, minutesLost: mEarly - mLate)
    }

    static func heartInsight(_ days: [DaySummary]) -> Insight? {
        let withBPM = days.filter { $0.nextMorningBPM != nil && $0.caffeineMg > 0 }
        guard withBPM.count >= 2 * minimumPerGroup, let split = median(withBPM.map(\.caffeineMg)) else { return nil }
        let high = withBPM.filter { $0.caffeineMg > split }.compactMap(\.nextMorningBPM)
        let low = withBPM.filter { $0.caffeineMg <= split }.compactMap(\.nextMorningBPM)
        guard high.count >= minimumPerGroup, low.count >= minimumPerGroup,
              let mHigh = mean(high), let mLow = mean(low), mHigh - mLow >= 3 else { return nil }
        return .heavyDaysRaiseMorningHR(thresholdMg: split, bpmIncrease: mHigh - mLow)
    }

    static func tensionInsight(_ days: [DaySummary]) -> Insight? {
        let rated = days.filter { $0.tension != nil && $0.caffeineMg > 0 }
        guard rated.count >= 2 * minimumPerGroup, let split = median(rated.map(\.caffeineMg)) else { return nil }
        let high = rated.filter { $0.caffeineMg > split }.compactMap { $0.tension.map(Double.init) }
        let low = rated.filter { $0.caffeineMg <= split }.compactMap { $0.tension.map(Double.init) }
        guard high.count >= minimumPerGroup, low.count >= minimumPerGroup,
              let mHigh = mean(high), let mLow = mean(low) else { return nil }
        let diff = mHigh - mLow
        guard abs(diff) >= 0.5 else { return nil }
        return diff > 0 ? .caffeineRaisesTension(thresholdMg: split, increase: diff) : .caffeineNotLinkedToTension
    }

    static func breathingInsight(_ days: [DaySummary]) -> Insight? {
        let drops = days.flatMap(\.breathingDrops)
        guard drops.count >= 2, let m = mean(drops) else { return nil }
        return m >= 2 ? .breathingHelps(sessions: drops.count, bpmDrop: m) : .breathingNeutral
    }

    static func habitInsight(_ days: [DaySummary]) -> Insight? {
        let nights = days.filter { $0.bedtimeLevelMg != nil && $0.caffeineMg > 0 }
        guard nights.count >= minimumPerGroup else { return nil }
        let late = nights.filter { $0.bedtimeLevelMg! > CaffeineModel.sleepThresholdMg }.count
        return late > 0 ? .lateNights(late: late, total: nights.count) : .balancedTiming
    }
}
