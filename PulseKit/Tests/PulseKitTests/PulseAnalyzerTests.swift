import XCTest
@testable import PulseKit

final class PulseAnalyzerTests: XCTestCase {
    private func run(_ scenario: SyntheticScenario, seconds: Double = 30, seed: UInt64 = 1) -> PulsePhase {
        var generator = SyntheticPulseGenerator(scenario: scenario, seed: seed)
        return PulseAnalyzer.analyze(generator.samples(seconds: seconds))
    }

    private func result(_ phase: PulsePhase, file: StaticString = #filePath, line: UInt = #line) -> PulseResult? {
        guard case .finished(let r) = phase else {
            XCTFail("Expected a finished measurement, got \(phase)", file: file, line: line)
            return nil
        }
        return r
    }

    func testAccurateAcrossHeartRateRange() {
        for bpm in [45.0, 52, 60, 72, 90, 120, 135, 150, 180] {
            for seed: UInt64 in 1...5 {
                let scenario = SyntheticScenario(id: "range", name: "range", bpm: bpm)
                guard let r = result(run(scenario, seed: seed)) else { continue }
                XCTAssertEqual(Double(r.bpm), bpm, accuracy: 3, "bpm \(bpm) seed \(seed)")
                XCTAssertEqual(r.quality, .good, "bpm \(bpm) seed \(seed)")
            }
        }
    }

    func testNoisySignalStillAccurate() {
        for seed: UInt64 in 1...5 {
            guard let r = result(run(.noisy, seed: seed)) else { continue }
            XCTAssertEqual(Double(r.bpm), 88, accuracy: 3, "seed \(seed)")
        }
    }

    /// The app may fail to read a pulse, but it must not be confidently wrong.
    func testNeverConfidentlyWrong() {
        let hard = [
            SyntheticScenario(id: "veryNoisy", name: "", bpm: 88, noise: 0.8),
            .motion,
        ]
        for scenario in hard {
            for seed: UInt64 in 1...10 {
                guard case .finished(let r) = run(scenario, seed: seed), r.quality == .good else { continue }
                XCTAssertEqual(Double(r.bpm), scenario.bpm, accuracy: 4, "\(scenario.id) seed \(seed)")
            }
        }
    }

    func testNoFingerNeverMeasures() {
        XCTAssertEqual(run(.noFinger), .noFinger)
    }

    func testFingerLiftRestartsMeasurement() {
        var generator = SyntheticPulseGenerator(scenario: .fingerLift)
        let analyzer = PulseAnalyzer()
        var phaseDuringLift: PulsePhase?
        var final: PulsePhase = .noFinger
        for sample in generator.samples(seconds: 36) {
            let update = analyzer.process(sample)
            if abs(sample.time - 9) < 0.01 { phaseDuringLift = update.phase }
            final = update.phase
        }
        XCTAssertEqual(phaseDuringLift, .noFinger)
        guard let r = result(final) else { return }
        XCTAssertEqual(Double(r.bpm), 80, accuracy: 3)
    }

    func testLiveBPMAppearsEarly() {
        var generator = SyntheticPulseGenerator(scenario: .resting)
        let analyzer = PulseAnalyzer()
        var liveAtEight: Int?
        for sample in generator.samples(seconds: 10) {
            let update = analyzer.process(sample)
            if abs(sample.time - 8) < 0.01 { liveAtEight = update.liveBPM }
        }
        let live = try? XCTUnwrap(liveAtEight)
        XCTAssertEqual(Double(live ?? 0), 72, accuracy: 4)
    }

    func testFinishedStateIsSticky() {
        var generator = SyntheticPulseGenerator(scenario: .resting)
        let analyzer = PulseAnalyzer()
        for sample in generator.samples(seconds: 30) { _ = analyzer.process(sample) }
        let extra = analyzer.process(PulseSample(time: 31, red: 0.3, green: 0.3, blue: 0.3))
        guard case .finished = extra.phase else { return XCTFail("Expected finished, got \(extra.phase)") }
        analyzer.reset()
        let afterReset = analyzer.process(PulseSample(time: 32, red: 0.3, green: 0.3, blue: 0.3))
        XCTAssertEqual(afterReset.phase, .noFinger)
    }
}

final class SignalProcessingTests: XCTestCase {
    func testBandpassRemovesConstantBrightness() {
        var filter = PulseBandpass(sampleRate: 30)
        filter.prime(with: 0.8)
        var last = 1.0
        for _ in 0..<300 { last = filter.process(0.8) }
        XCTAssertEqual(last, 0, accuracy: 1e-9)
    }

    func testBandpassKeepsHeartBandAndRejectsDrift() {
        func amplitude(at hz: Double) -> Double {
            var filter = PulseBandpass(sampleRate: 30)
            var peak = 0.0
            for i in 0..<900 {
                let y = filter.process(sin(2 * Double.pi * hz * Double(i) / 30))
                if i > 450 { peak = max(peak, abs(y)) }
            }
            return peak
        }
        XCTAssertGreaterThan(amplitude(at: 1.2), 0.8)
        XCTAssertGreaterThan(amplitude(at: 2.5), 0.8)
        XCTAssertLessThan(amplitude(at: 0.05), 0.05)
        XCTAssertLessThan(amplitude(at: 10), 0.2)
    }

    func testSpectralEstimateFindsSine() {
        var rng = SplitMix64(seed: 3)
        let points = (0..<600).map { i -> SignalPoint in
            let t = Double(i) / 30
            return SignalPoint(time: t, value: sin(2 * Double.pi * 1.5 * t) + 0.3 * rng.nextGaussian())
        }
        let estimate = SpectralEstimator.estimate(points)
        XCTAssertEqual(estimate?.bpm ?? 0, 90, accuracy: 1)
    }

    func testFingerDetector() {
        let detector = FingerDetector()
        XCTAssertTrue(detector.isFingerPresent(PulseSample(time: 0, red: 0.8, green: 0.1, blue: 0.05)))
        XCTAssertFalse(detector.isFingerPresent(PulseSample(time: 0, red: 0.3, green: 0.3, blue: 0.3)))
        XCTAssertFalse(detector.isFingerPresent(PulseSample(time: 0, red: 0.1, green: 0.02, blue: 0.01)))
    }

    func testTraceCSVAndError() {
        var generator = SyntheticPulseGenerator(scenario: .resting)
        let samples = generator.samples(seconds: 2)
        let result = PulseResult(bpm: 74, quality: .good, beatBPM: 74, spectralBPM: 73,
                                 spectralProminence: 50, beatCount: 24,
                                 consistentIntervalRatio: 1, duration: 20)
        let trace = PulseTrace(device: "test", source: "synthetic", referenceBPM: 71,
                               result: result, samples: samples)
        XCTAssertEqual(trace.error, 3)
        XCTAssertEqual(trace.sampleRate ?? 0, 30, accuracy: 0.01)
        XCTAssertEqual(trace.samplesCSV().split(separator: "\n").count, samples.count + 1)
        XCTAssertEqual(PulseTrace.summaryCSV([trace]).split(separator: "\n").count, 2)
    }
}
