import Foundation

/// One camera frame reduced to the mean color of its measurement region.
public struct PulseSample: Codable, Equatable, Sendable {
    /// Seconds on a monotonic clock. Only differences matter.
    public var time: TimeInterval
    /// Mean channel values, 0...1.
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(time: TimeInterval, red: Double, green: Double, blue: Double) {
        self.time = time
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Decides whether a fingertip lit by the flash is covering the lens.
/// A covered, lit lens produces a bright, strongly red image.
public struct FingerDetector: Sendable, Equatable {
    public var minRed: Double
    /// Red must be at least this many times the brighter of green and blue.
    public var minRedDominance: Double

    public init(minRed: Double = 0.35, minRedDominance: Double = 1.6) {
        self.minRed = minRed
        self.minRedDominance = minRedDominance
    }

    public func isFingerPresent(_ sample: PulseSample) -> Bool {
        let other = max(sample.green, sample.blue, 0.001)
        return sample.red >= minRed && sample.red / other >= minRedDominance
    }
}
