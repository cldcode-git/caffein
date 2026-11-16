import Foundation

/// The user's own normal morning resting heart rate.
public struct HeartBaseline: Equatable, Sendable {
    public var median: Double
    /// Robust spread (scaled median absolute deviation), at least 3 BPM.
    public var spread: Double
    public var sampleCount: Int
}

public enum StressLevel: String, Sendable, CaseIterable {
    case low, moderate, high
}

public struct StressAssessment: Equatable, Sendable {
    public var level: StressLevel
    /// 0 (calm) ... 1 (high).
    public var score: Double
    /// Today's morning heart rate minus the personal normal, in BPM.
    public var heartRateDeviation: Double?
    public var tensionScore: Int?
}

/// Combines how far this morning's resting pulse is from the personal normal
/// with the user's own tension rating. Neither alone is a diagnosis; together
/// they give a simple, explainable daily signal.
public enum StressIndex {
    public static let minimumBaselineDays = 5
    public static let baselineWindow = 14

    /// `morningBPMs` newest first; uses at most the last 14.
    public static func baseline(morningBPMs: [Double]) -> HeartBaseline? {
        let recent = Array(morningBPMs.prefix(baselineWindow))
        guard recent.count >= minimumBaselineDays, let m = median(recent) else { return nil }
        let mad = median(recent.map { abs($0 - m) }) ?? 0
        return HeartBaseline(median: m, spread: max(3, 1.4826 * mad), sampleCount: recent.count)
    }

    public static func assess(morningBPM: Double?, baseline: HeartBaseline?,
                              tensionScore: Int?) -> StressAssessment? {
        var parts: [Double] = []
        var deviation: Double?
        if let bpm = morningBPM, let baseline {
            let d = bpm - baseline.median
            deviation = d
            let z = d / baseline.spread
            // z = -1 → 0, z = +1 → 0.5, z = +3 → 1
            parts.append(min(max((z + 1) / 4, 0), 1))
        }
        if let t = tensionScore {
            parts.append(Double(min(max(t, 1), 5) - 1) / 4)
        }
        guard !parts.isEmpty else { return nil }
        let score = parts.reduce(0, +) / Double(parts.count)
        let level: StressLevel = score < 0.34 ? .low : (score < 0.67 ? .moderate : .high)
        return StressAssessment(level: level, score: score, heartRateDeviation: deviation, tensionScore: tensionScore)
    }
}

func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let s = values.sorted()
    let mid = s.count / 2
    return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
}

func mean(_ values: [Double]) -> Double? {
    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
}
