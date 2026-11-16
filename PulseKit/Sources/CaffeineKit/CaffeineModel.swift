import Foundation

public struct CaffeineDose: Equatable, Sendable {
    public var time: Date
    public var milligrams: Double

    public init(time: Date, milligrams: Double) {
        self.time = time
        self.milligrams = milligrams
    }
}

/// How quickly the body clears caffeine. Half-life varies roughly 2–10 hours
/// between people (genetics, smoking, pregnancy, oral contraceptives, liver).
public enum CaffeineSensitivity: String, CaseIterable, Codable, Sendable, Identifiable {
    case fast, normal, slow
    public var id: String { rawValue }

    public var halfLifeHours: Double {
        switch self {
        case .fast: 3.5
        case .normal: 5
        case .slow: 7
        }
    }
}

public struct CurvePoint: Equatable, Sendable, Identifiable {
    public var time: Date
    public var milligrams: Double
    public var id: Date { time }
}

/// Caffeine in the body over time: one-compartment model with first-order
/// absorption (peak about 45 minutes after drinking) and first-order
/// elimination set by the half-life.
public struct CaffeineModel: Sendable {
    public var halfLifeHours: Double
    public var absorptionRatePerHour: Double

    /// Remaining caffeine at bedtime above which sleep is likely affected.
    /// Conservative on purpose: studies find a typical coffee can still
    /// shorten sleep when drunk up to ~8 hours before bed.
    public static let sleepThresholdMg: Double = 30
    /// Commonly cited daily upper reference for healthy adults (EFSA, FDA).
    public static let dailyReferenceMg: Double = 400
    /// Commonly cited single-serving reference for healthy adults (EFSA).
    public static let singleServingReferenceMg: Double = 200

    public init(halfLifeHours: Double = 5, absorptionRatePerHour: Double = 5) {
        self.halfLifeHours = halfLifeHours
        self.absorptionRatePerHour = absorptionRatePerHour
    }

    public init(sensitivity: CaffeineSensitivity) {
        self.init(halfLifeHours: sensitivity.halfLifeHours)
    }

    private var eliminationRate: Double { log(2) / halfLifeHours }

    /// Milligrams from one dose still in the body at `date`.
    public func amount(of dose: CaffeineDose, at date: Date) -> Double {
        let hours = date.timeIntervalSince(dose.time) / 3600
        guard hours > 0 else { return 0 }
        let ka = absorptionRatePerHour, ke = eliminationRate
        return dose.milligrams * ka / (ka - ke) * (exp(-ke * hours) - exp(-ka * hours))
    }

    public func level(_ doses: [CaffeineDose], at date: Date) -> Double {
        doses.reduce(0) { $0 + amount(of: $1, at: date) }
    }

    public func curve(_ doses: [CaffeineDose], from start: Date, to end: Date,
                      step: TimeInterval = 600) -> [CurvePoint] {
        guard end > start else { return [] }
        return stride(from: start.timeIntervalSinceReferenceDate,
                      through: end.timeIntervalSinceReferenceDate, by: step).map {
            let t = Date(timeIntervalSinceReferenceDate: $0)
            return CurvePoint(time: t, milligrams: level(doses, at: t))
        }
    }

    /// Highest level during the first hours of sleep.
    public func peakDuringSleep(_ doses: [CaffeineDose], bedtime: Date,
                                window: TimeInterval = 2 * 3600) -> Double {
        stride(from: 0, through: window, by: 900)
            .map { level(doses, at: bedtime.addingTimeInterval($0)) }
            .max() ?? 0
    }

    /// The latest time one more drink of `nextDoseMg` keeps the caffeine
    /// level during early sleep at or below the threshold. Nil means even
    /// without another drink the threshold is already exceeded.
    public func latestIntakeTime(existing doses: [CaffeineDose], nextDoseMg: Double,
                                 bedtime: Date, earliest: Date,
                                 threshold: Double = CaffeineModel.sleepThresholdMg,
                                 step: TimeInterval = 900) -> Date? {
        guard peakDuringSleep(doses, bedtime: bedtime) <= threshold else { return nil }
        var t = bedtime
        while t >= earliest {
            let candidate = doses + [CaffeineDose(time: t, milligrams: nextDoseMg)]
            if peakDuringSleep(candidate, bedtime: bedtime) <= threshold {
                return t
            }
            t -= step
        }
        return earliest
    }

    /// When the level falls below `milligrams`, searching up to two days ahead.
    public func timeWhenBelow(_ milligrams: Double, doses: [CaffeineDose], after start: Date) -> Date? {
        // Skip the absorption phase of the latest drink, where the level is
        // still rising from zero.
        let absorbed = doses.map(\.time).max().map { $0.addingTimeInterval(3600) } ?? start
        var t = max(start, absorbed)
        let end = start.addingTimeInterval(48 * 3600)
        while t <= end {
            if level(doses, at: t) < milligrams { return t }
            t += 600
        }
        return nil
    }
}
