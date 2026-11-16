import Foundation

/// A simple daily drinking-water suggestion.
///
/// Water does not speed up how fast the body clears caffeine (the liver
/// does that at its own pace). The extra amount only offsets caffeine's mild
/// diuretic effect, which matters mostly at higher daily amounts.
public enum WaterGuide {
    /// Common rule of thumb for fluid from drinks: about 30 ml per kg.
    public static let mlPerKg: Double = 30
    /// Used until the user enters a weight.
    public static let defaultWeightKg: Double = 70
    /// Extra water per milligram of caffeine (≈ one glass per two coffees).
    public static let extraMlPerMgCaffeine: Double = 1
    public static let glassMl: Double = 200

    public struct Target: Equatable, Sendable {
        public var baseMl: Double
        public var caffeineExtraMl: Double
        public var totalMl: Double { baseMl + caffeineExtraMl }
        public var glasses: Int { Int((totalMl / WaterGuide.glassMl).rounded(.up)) }
    }

    public static func target(weightKg: Double?, caffeineTodayMg: Double) -> Target {
        let weight = (weightKg ?? 0) > 0 ? weightKg! : defaultWeightKg
        let base = (weight * mlPerKg / 100).rounded() * 100
        let extra = (max(0, caffeineTodayMg) * extraMlPerMgCaffeine / 50).rounded() * 50
        return Target(baseMl: base, caffeineExtraMl: extra)
    }
}
