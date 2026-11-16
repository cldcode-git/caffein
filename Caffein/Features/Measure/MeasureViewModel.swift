import Foundation
import Observation
import PulseKit
import UIKit

/// Drives one camera pulse measurement of a given length. A reading of poor
/// quality never produces a number: the attempt is retried, and after two
/// poor attempts the measurement reports `.failed`.
@MainActor
@Observable
final class PulseMeasurementModel {
    enum Status: Equatable {
        case idle
        case running
        /// Stopped after a long time without a finger, to save battery.
        case paused
        case needsPermission
        case unavailable(String)
        /// Two poor attempts in a row. The user can retry or skip.
        case failed
        case done(PulseResult)
    }

    static let waveformCapacity = 120 // 4 s at 30 fps
    private static let idleTimeout: TimeInterval = 45
    private static let maxAttempts = 2

    let duration: TimeInterval

    private(set) var status: Status = .idle
    private(set) var phase: PulsePhase = .noFinger
    private(set) var liveBPM: Int?
    private(set) var beatTick = 0
    private(set) var waveform: [Double] = []
    private(set) var isMoving = false
    private(set) var retryHint: String?

    // QA overlay diagnostics
    private(set) var sourceLabel = ""
    private(set) var framesPerSecond: Double = 0
    private(set) var lastSample: PulseSample?

    private let analyzer: PulseAnalyzer
    private let haptics = BeatHaptics()
    private let motion = MotionMonitor()
    private var source: SignalSource?
    private var attemptSamples: [PulseSample] = []
    private var poorAttempts = 0
    private var lastFingerAt = Date()
    private var lastSampleTime: TimeInterval?

    init(duration: TimeInterval) {
        self.duration = duration
        var config = PulseAnalyzerConfig()
        config.measureDuration = duration
        analyzer = PulseAnalyzer(config: config)
    }

    var hapticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.hapticsEnabled)
    }

    var result: PulseResult? {
        if case .done(let r) = status { return r }
        return nil
    }

    // MARK: - Lifecycle

    func start() async {
        guard source == nil else { return }
        switch status {
        case .done, .failed: return
        default: break
        }
        let newSource = SignalSourceFactory.make()
        newSource.onSample = { [weak self] sample in
            // Main queue keeps samples in order.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(sample) }
            }
        }
        source = newSource
        sourceLabel = newSource.label
        do {
            try await newSource.start()
            // stop() may have run while we waited (screen left, app backgrounded).
            guard source === newSource else {
                newSource.stop()
                return
            }
            status = .running
            lastFingerAt = Date()
            haptics.prepare()
            motion.start { [weak self] moving in self?.isMoving = moving }
            UIApplication.shared.isIdleTimerDisabled = true
        } catch SignalSourceError.cameraPermissionDenied {
            if source === newSource { source = nil }
            status = .needsPermission
        } catch {
            if source === newSource { source = nil }
            status = .unavailable(error.localizedDescription)
        }
    }

    func stop() {
        stopSource()
        switch status {
        case .running: status = .idle
        default: break
        }
    }

    /// Start over after a failure.
    func retry() async {
        poorAttempts = 0
        retryHint = nil
        status = .idle
        await start()
    }

    private func stopSource() {
        source?.stop()
        source = nil
        motion.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        analyzer.reset()
        phase = .noFinger
        liveBPM = nil
        waveform.removeAll()
        attemptSamples.removeAll()
        lastSampleTime = nil
        isMoving = false
    }

    // MARK: - Samples

    private func handle(_ sample: PulseSample) {
        guard source != nil else { return }
        updateFrameRate(sample)
        lastSample = sample

        let previous = phase
        let update = analyzer.process(sample)
        phase = update.phase
        liveBPM = update.liveBPM

        if update.isFingerPresent {
            lastFingerAt = Date()
            attemptSamples.append(sample)
        }

        if let value = update.filteredValue {
            waveform.append(value)
            if waveform.count > Self.waveformCapacity {
                waveform.removeFirst(waveform.count - Self.waveformCapacity)
            }
        }

        if update.isBeat {
            beatTick += 1
            if hapticsEnabled { haptics.beat() }
        }

        switch (previous, phase) {
        case (.noFinger, .settling):
            source?.setExposureLocked(true)
        case (_, .noFinger) where previous != .noFinger:
            source?.setExposureLocked(false)
            waveform.removeAll()
            attemptSamples.removeAll()
        default:
            break
        }

        switch phase {
        case .finished(let result):
            finishAttempt(result)
        case .failed:
            finishAttempt(nil)
        case .noFinger:
            if Date().timeIntervalSince(lastFingerAt) > Self.idleTimeout {
                stopSource()
                status = .paused
            }
        default:
            break
        }
    }

    private func finishAttempt(_ result: PulseResult?) {
        if let result, result.quality != .poor {
            stopSource()
            status = .done(result)
            return
        }

        poorAttempts += 1
        if poorAttempts >= Self.maxAttempts {
            stopSource()
            status = .failed
            return
        }
        // Try again right away, the finger is probably still there.
        retryHint = L("Sinyal net değildi, tekrar ölçüyoruz. Parmağını bastırmadan, sabit tut.")
        analyzer.reset()
        phase = .noFinger
        attemptSamples.removeAll()
        waveform.removeAll()
        source?.setExposureLocked(false)
    }

    private func updateFrameRate(_ sample: PulseSample) {
        defer { lastSampleTime = sample.time }
        guard let last = lastSampleTime, sample.time > last else { return }
        let instant = 1 / (sample.time - last)
        framesPerSecond = framesPerSecond == 0 ? instant : framesPerSecond * 0.9 + instant * 0.1
    }
}
