import Foundation

public struct SignalPoint: Codable, Equatable, Sendable {
    public var time: TimeInterval
    public var value: Double

    public init(time: TimeInterval, value: Double) {
        self.time = time
        self.value = value
    }
}

/// Causal beat detector for live feedback (haptic tick, live BPM).
/// The final result does not depend on it; see `OfflineBeatFinder`.
public struct LiveBeatDetector: Sendable {
    public var minInterval: TimeInterval = 0.3
    public var thresholdRatio = 0.5
    public var window: TimeInterval = 2.5

    private var recent: [SignalPoint] = []
    private var lastBeat: TimeInterval?
    private var intervals: [TimeInterval] = []

    public init() {}

    public mutating func reset() {
        recent.removeAll()
        lastBeat = nil
        intervals.removeAll()
    }

    /// Median of the most recent beat intervals as BPM, once there are enough.
    public var liveBPM: Double? {
        guard intervals.count >= 3, let m = median(intervals), m > 0 else { return nil }
        return 60 / m
    }

    /// Feeds one filtered value. Returns the beat time when the previous
    /// sample turns out to be a beat peak.
    public mutating func process(_ point: SignalPoint) -> TimeInterval? {
        recent.append(point)
        while let first = recent.first, first.time < point.time - window {
            recent.removeFirst()
        }
        let n = recent.count
        guard n >= 3 else { return nil }
        let a = recent[n - 3], b = recent[n - 2], c = recent[n - 1]
        guard b.value > a.value, b.value >= c.value, b.value > 0 else { return nil }
        let windowMax = recent.map(\.value).max() ?? 0
        guard b.value >= thresholdRatio * windowMax else { return nil }

        let beatTime = b.time + parabolicOffset(a.value, b.value, c.value) * (c.time - b.time)
        if let last = lastBeat {
            let refractory = max(minInterval, 0.5 * (median(intervals) ?? 0))
            guard beatTime - last >= refractory else { return nil }
            intervals.append(beatTime - last)
            if intervals.count > 8 { intervals.removeFirst(intervals.count - 8) }
        }
        lastBeat = beatTime
        return beatTime
    }
}

/// Non-causal peak picking over a whole recorded window. Peaks are accepted
/// tallest-first and must be at least `minDistance` apart, so the smaller
/// dicrotic bump and noise wiggles next to a real beat are dropped.
public enum OfflineBeatFinder {
    public static func beatTimes(in points: [SignalPoint],
                                 minDistance: TimeInterval,
                                 localWindow: TimeInterval = 1.5,
                                 relativeHeight: Double = 0.4) -> [TimeInterval] {
        guard points.count >= 3 else { return [] }
        var candidates: [Int] = []
        for i in 1..<(points.count - 1) {
            let v = points[i].value
            if v > 0, v > points[i - 1].value, v >= points[i + 1].value {
                candidates.append(i)
            }
        }
        candidates.sort { points[$0].value > points[$1].value }

        var accepted: [Int] = []
        for i in candidates {
            let t = points[i].time
            if accepted.allSatisfy({ abs(points[$0].time - t) >= minDistance }) {
                accepted.append(i)
            }
        }

        // Drop peaks that are small compared with their neighbourhood.
        let kept = accepted.filter { i in
            let t = points[i].time
            let localMax = points
                .filter { abs($0.time - t) <= localWindow }
                .map(\.value)
                .max() ?? points[i].value
            return points[i].value >= relativeHeight * localMax
        }

        return kept.sorted().map { i in
            let dt = points[i + 1].time - points[i].time
            return points[i].time + parabolicOffset(points[i - 1].value, points[i].value, points[i + 1].value) * dt
        }
    }
}

/// Estimates the dominant pulse frequency with a direct Fourier sum over the
/// real sample times, so dropped or jittered frames do not bias it.
public enum SpectralEstimator {
    public struct Estimate: Equatable, Sendable {
        public var bpm: Double
        /// Peak power divided by median power across the band. Higher is cleaner.
        public var prominence: Double
    }

    public static func estimate(_ points: [SignalPoint],
                                minBPM: Double = 40,
                                maxBPM: Double = 200,
                                stepBPM: Double = 0.25) -> Estimate? {
        guard points.count >= 64, let t0 = points.first?.time else { return nil }
        let n = points.count
        let mean = points.map(\.value).reduce(0, +) / Double(n)
        let windowed: [(t: Double, v: Double)] = points.enumerated().map { i, p in
            let hann = 0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(n - 1))
            return (p.time - t0, (p.value - mean) * hann)
        }

        func power(atBPM bpm: Double) -> Double {
            let w = 2 * Double.pi * bpm / 60
            var re = 0.0, im = 0.0
            for s in windowed {
                re += s.v * cos(w * s.t)
                im -= s.v * sin(w * s.t)
            }
            return re * re + im * im
        }

        var bpms: [Double] = []
        var powers: [Double] = []
        var bpm = minBPM
        while bpm <= maxBPM {
            bpms.append(bpm)
            powers.append(power(atBPM: bpm))
            bpm += stepBPM
        }
        guard let peakIndex = powers.indices.max(by: { powers[$0] < powers[$1] }),
              let medianPower = median(powers), medianPower > 0 else { return nil }

        var best = bpms[peakIndex]
        var bestPower = powers[peakIndex]
        // PPG harmonics can outshine a weak fundamental. Prefer half the
        // frequency when it carries comparable power.
        let half = best / 2
        if half >= minBPM {
            let halfPower = power(atBPM: half)
            if halfPower > 0.5 * bestPower {
                best = half
                bestPower = halfPower
            }
        }
        return Estimate(bpm: best, prominence: bestPower / medianPower)
    }
}

// MARK: - Helpers

/// Vertex of the parabola through three equally spaced samples, as an
/// offset from the middle one in sample units (-0.5...0.5).
func parabolicOffset(_ y0: Double, _ y1: Double, _ y2: Double) -> Double {
    let denom = y0 - 2 * y1 + y2
    guard denom < 0 else { return 0 }
    return min(max(0.5 * (y0 - y2) / denom, -0.5), 0.5)
}

func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let s = values.sorted()
    let mid = s.count / 2
    return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
}
