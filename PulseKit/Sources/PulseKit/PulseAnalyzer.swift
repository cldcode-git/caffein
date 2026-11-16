import Foundation

public struct PulseResult: Codable, Equatable, Sendable {
    public enum Quality: String, Codable, Sendable, CaseIterable {
        case good, fair, poor
    }

    public var bpm: Int
    public var quality: Quality
    /// Diagnostics, shown in the QA panel.
    public var beatBPM: Double?
    public var spectralBPM: Double?
    public var spectralProminence: Double?
    public var beatCount: Int
    /// Share of beat intervals that agreed with the median interval.
    public var consistentIntervalRatio: Double
    public var duration: TimeInterval

    public init(bpm: Int, quality: Quality, beatBPM: Double?, spectralBPM: Double?,
                spectralProminence: Double?, beatCount: Int,
                consistentIntervalRatio: Double, duration: TimeInterval) {
        self.bpm = bpm
        self.quality = quality
        self.beatBPM = beatBPM
        self.spectralBPM = spectralBPM
        self.spectralProminence = spectralProminence
        self.beatCount = beatCount
        self.consistentIntervalRatio = consistentIntervalRatio
        self.duration = duration
    }
}

public enum PulsePhase: Equatable, Sendable {
    case noFinger
    /// Finger detected; waiting for exposure and the filter to settle.
    case settling(progress: Double)
    case measuring(progress: Double)
    case finished(PulseResult)
    /// Measurement completed but no usable pulse was found.
    case failed
}

public struct PulseUpdate: Sendable {
    public var phase: PulsePhase
    public var isFingerPresent: Bool
    /// Band-passed signal, inverted so beats point up. Nil while no finger.
    public var filteredValue: Double?
    public var isBeat: Bool
    public var liveBPM: Int?
}

public struct PulseAnalyzerConfig: Sendable, Equatable {
    public var nominalSampleRate: Double = 30
    public var settleDuration: TimeInterval = 2
    public var measureDuration: TimeInterval = 20
    /// A finger lifted for less than this is treated as a glitch.
    public var fingerLossTolerance: TimeInterval = 0.5
    public var minBPM: Double = 40
    public var maxBPM: Double = 200
    public var fingerDetector = FingerDetector()

    public init() {}
}

/// Streaming pulse analysis. Feed every camera sample to `process(_:)`.
public final class PulseAnalyzer {
    public let config: PulseAnalyzerConfig

    private var phase: PulsePhase = .noFinger
    private var filter: PulseBandpass
    private var liveDetector = LiveBeatDetector()
    private var fingerSince: TimeInterval?
    private var lastFingerSeen: TimeInterval?
    private var measureStart: TimeInterval?
    private var measured: [SignalPoint] = []

    public init(config: PulseAnalyzerConfig = PulseAnalyzerConfig()) {
        self.config = config
        filter = PulseBandpass(sampleRate: config.nominalSampleRate)
        liveDetector.minInterval = 60 / config.maxBPM
    }

    public func reset() {
        phase = .noFinger
        fingerSince = nil
        lastFingerSeen = nil
        resetMeasurement()
    }

    private func resetMeasurement() {
        measureStart = nil
        measured.removeAll(keepingCapacity: true)
        liveDetector.reset()
    }

    public func process(_ sample: PulseSample) -> PulseUpdate {
        switch phase {
        case .finished, .failed:
            return PulseUpdate(phase: phase, isFingerPresent: false, filteredValue: nil, isBeat: false, liveBPM: nil)
        default:
            break
        }

        let t = sample.time
        guard config.fingerDetector.isFingerPresent(sample) else {
            if fingerSince != nil, let last = lastFingerSeen, t - last <= config.fingerLossTolerance {
                // Brief glitch: skip the frame but keep the measurement.
                return PulseUpdate(phase: phase, isFingerPresent: false, filteredValue: nil, isBeat: false, liveBPM: currentLiveBPM)
            }
            reset()
            return PulseUpdate(phase: .noFinger, isFingerPresent: false, filteredValue: nil, isBeat: false, liveBPM: nil)
        }

        if fingerSince == nil {
            fingerSince = t
            filter.prime(with: sample.red)
        }
        lastFingerSeen = t
        // Blood volume rises with each beat and absorbs more light, so the
        // raw red level dips on a beat. Invert so beats are peaks.
        let value = -filter.process(sample.red)

        let sinceFinger = t - (fingerSince ?? t)
        if sinceFinger < config.settleDuration {
            phase = .settling(progress: sinceFinger / config.settleDuration)
            return PulseUpdate(phase: phase, isFingerPresent: true, filteredValue: value, isBeat: false, liveBPM: nil)
        }

        if measureStart == nil { measureStart = t }
        let point = SignalPoint(time: t, value: value)
        measured.append(point)
        let isBeat = liveDetector.process(point) != nil

        let elapsed = t - (measureStart ?? t)
        if elapsed >= config.measureDuration {
            if let result = Self.evaluate(measured, config: config) {
                phase = .finished(result)
            } else {
                phase = .failed
            }
        } else {
            phase = .measuring(progress: elapsed / config.measureDuration)
        }
        return PulseUpdate(phase: phase, isFingerPresent: true, filteredValue: value, isBeat: isBeat, liveBPM: currentLiveBPM)
    }

    private var currentLiveBPM: Int? {
        guard let bpm = liveDetector.liveBPM, bpm >= config.minBPM, bpm <= config.maxBPM else { return nil }
        return Int(bpm.rounded())
    }

    /// Runs a whole recording through a fresh analyzer. Used by tests and
    /// by the QA panel to re-analyse saved traces after algorithm changes.
    public static func analyze(_ samples: [PulseSample],
                               config: PulseAnalyzerConfig = PulseAnalyzerConfig()) -> PulsePhase {
        let analyzer = PulseAnalyzer(config: config)
        var last: PulsePhase = .noFinger
        for sample in samples {
            last = analyzer.process(sample).phase
            switch last {
            case .finished, .failed: return last
            default: continue
            }
        }
        return last
    }

    // MARK: - Final evaluation

    static func evaluate(_ points: [SignalPoint], config: PulseAnalyzerConfig) -> PulseResult? {
        guard let first = points.first, let last = points.last else { return nil }
        let duration = last.time - first.time

        let spectral = SpectralEstimator.estimate(points, minBPM: config.minBPM, maxBPM: config.maxBPM)
        let expectedInterval = spectral.map { 60 / $0.bpm }
        let minDistance = max(60 / config.maxBPM, 0.6 * (expectedInterval ?? 0))
        let beats = OfflineBeatFinder.beatTimes(in: points, minDistance: minDistance)

        let intervals = zip(beats.dropFirst(), beats).map { $0 - $1 }
            .filter { $0 >= 60 / config.maxBPM && $0 <= 60 / config.minBPM }
        var beatBPM: Double?
        var consistentRatio = 0.0
        if let m = median(intervals) {
            let consistent = intervals.filter { abs($0 - m) <= 0.2 * m }
            consistentRatio = Double(consistent.count) / Double(intervals.count)
            if consistent.count >= 5 {
                beatBPM = 60 / (consistent.reduce(0, +) / Double(consistent.count))
            }
        }

        let quality: PulseResult.Quality
        let bpm: Double
        switch (beatBPM, spectral) {
        case let (beat?, spec?):
            let diff = abs(beat - spec.bpm)
            if diff <= 4, consistentRatio >= 0.8, spec.prominence >= 3 {
                quality = .good
                bpm = beat
            } else if diff <= 8, consistentRatio >= 0.6 {
                quality = .fair
                bpm = (beat + spec.bpm) / 2
            } else {
                quality = .poor
                bpm = consistentRatio >= 0.8 ? beat : spec.bpm
            }
        case let (beat?, nil):
            quality = .poor
            bpm = beat
        case let (nil, spec?):
            quality = .poor
            bpm = spec.bpm
        case (nil, nil):
            return nil
        }

        return PulseResult(
            bpm: Int(bpm.rounded()),
            quality: quality,
            beatBPM: beatBPM,
            spectralBPM: spectral?.bpm,
            spectralProminence: spectral?.prominence,
            beatCount: beats.count,
            consistentIntervalRatio: consistentRatio,
            duration: duration
        )
    }
}
