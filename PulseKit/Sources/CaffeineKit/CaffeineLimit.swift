import Foundation

/// What the daily limit is based on. Entered at onboarding.
public struct CaffeineProfile: Equatable, Sendable {
    public var age: Int
    public var weightKg: Double
    public var pregnantOrBreastfeeding: Bool

    public init(age: Int, weightKg: Double, pregnantOrBreastfeeding: Bool = false) {
        self.age = age
        self.weightKg = weightKg
        self.pregnantOrBreastfeeding = pregnantOrBreastfeeding
    }
}

/// Daily caffeine amount considered tolerable for this person, following
/// EFSA's 2015 safety opinion:
/// - Healthy adults: 400 mg a day, which EFSA derives for a 70 kg adult
///   (≈5.7 mg per kg). Lighter adults get proportionally less; the limit
///   never goes above 400 mg.
/// - Under 18: 3 mg per kg a day.
/// - Pregnant or breastfeeding: at most 200 mg a day.
public enum CaffeineLimit {
    public static let adultMgPerKg = CaffeineModel.dailyReferenceMg / 70
    public static let youthMgPerKg: Double = 3
    public static let pregnancyMaxMg: Double = 200
    public static let adultAge = 18

    public enum Basis: Equatable, Sendable {
        /// No age/weight yet: the general adult reference.
        case generalReference
        case adultWeight
        case adultCap
        case youthWeight
        case pregnancy
    }

    public struct Result: Equatable, Sendable {
        public var dailyMg: Double
        public var basis: Basis
    }

    public static func daily(for profile: CaffeineProfile?) -> Result {
        guard let p = profile, p.weightKg > 0, p.age > 0 else {
            return Result(dailyMg: CaffeineModel.dailyReferenceMg, basis: .generalReference)
        }
        var mg: Double
        var basis: Basis
        if p.age < adultAge {
            mg = youthMgPerKg * p.weightKg
            basis = .youthWeight
        } else if adultMgPerKg * p.weightKg >= CaffeineModel.dailyReferenceMg {
            mg = CaffeineModel.dailyReferenceMg
            basis = .adultCap
        } else {
            mg = adultMgPerKg * p.weightKg
            basis = .adultWeight
        }
        if p.pregnantOrBreastfeeding && mg > pregnancyMaxMg {
            mg = pregnancyMaxMg
            basis = .pregnancy
        }
        return Result(dailyMg: (mg / 5).rounded(.down) * 5, basis: basis)
    }

    public enum Status: Equatable, Sendable {
        case below
        /// At 80 % of the limit, or the next typical drink would pass it.
        case approaching
        case over
    }

    public static func status(todayMg: Double, nextDoseMg: Double, limitMg: Double) -> Status {
        if todayMg > limitMg { return .over }
        if todayMg >= 0.8 * limitMg || todayMg + nextDoseMg > limitMg { return .approaching }
        return .below
    }
}
