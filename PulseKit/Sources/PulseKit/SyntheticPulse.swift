import Foundation

/// A scripted fingertip signal, for the simulator (which has no camera),
/// unit tests and QA comparisons.
public struct SyntheticScenario: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var bpm: Double
    /// Standard deviation of white noise, relative to a pulse amplitude of 1.
    public var noise: Double
    /// Beat-to-beat rate variation (standard deviation, fraction of rate).
    public var variability: Double
    /// When the finger lands on the lens. Nil means never.
    public var fingerOnAt: TimeInterval?
    /// A span during which the finger is lifted again.
    public var fingerOffWindow: ClosedRange<TimeInterval>?
    /// Adds a large hand-movement artifact every few seconds.
    public var motionBursts: Bool

    public init(id: String, name: String, bpm: Double, noise: Double = 0.05,
                variability: Double = 0.03, fingerOnAt: TimeInterval? = 1,
                fingerOffWindow: ClosedRange<TimeInterval>? = nil, motionBursts: Bool = false) {
        self.id = id
        self.name = name
        self.bpm = bpm
        self.noise = noise
        self.variability = variability
        self.fingerOnAt = fingerOnAt
        self.fingerOffWindow = fingerOffWindow
        self.motionBursts = motionBursts
    }

    public static let resting = SyntheticScenario(id: "resting", name: "Dinlenme · 72", bpm: 72)
    public static let athlete = SyntheticScenario(id: "athlete", name: "Sporcu · 52", bpm: 52)
    public static let exercise = SyntheticScenario(id: "exercise", name: "Egzersiz sonrası · 135", bpm: 135)
    public static let noisy = SyntheticScenario(id: "noisy", name: "Gürültülü · 88", bpm: 88, noise: 0.3)
    public static let fingerLift = SyntheticScenario(id: "fingerLift", name: "Parmak kalkıyor · 80", bpm: 80, fingerOffWindow: 8...10)
    public static let motion = SyntheticScenario(id: "motion", name: "Hareketli · 76", bpm: 76, motionBursts: true)
    public static let noFinger = SyntheticScenario(id: "noFinger", name: "Parmak yok", bpm: 70, fingerOnAt: nil)

    public static let presets: [SyntheticScenario] = [
        .resting, .athlete, .exercise, .noisy, .fingerLift, .motion, .noFinger,
    ]
}

public struct SyntheticPulseGenerator: Sendable {
    public let scenario: SyntheticScenario
    public let sampleRate: Double

    private var rng: SplitMix64
    private var index = 0
    private var beatPhase = 0.0
    private var rateFactor = 1.0
    private var motionOffset = 0.0

    /// Relative size of the pulse in the red channel of a lit fingertip.
    private let pulseAmplitude = 0.01

    public init(scenario: SyntheticScenario, sampleRate: Double = 30, seed: UInt64 = 1) {
        self.scenario = scenario
        self.sampleRate = sampleRate
        rng = SplitMix64(seed: seed)
    }

    public mutating func next() -> PulseSample {
        let t = Double(index) / sampleRate
        index += 1

        beatPhase += (1 / sampleRate) * (scenario.bpm / 60) * rateFactor
        if beatPhase >= 1 {
            beatPhase -= 1
            rateFactor = max(0.7, 1 + scenario.variability * rng.nextGaussian())
        }

        let fingerOn: Bool = {
            guard let on = scenario.fingerOnAt, t >= on else { return false }
            if let off = scenario.fingerOffWindow, off.contains(t) { return false }
            return true
        }()

        guard fingerOn else {
            // Uncovered lens: grey room light.
            let g = 0.3 + 0.01 * rng.nextGaussian()
            return PulseSample(time: t, red: g, green: g, blue: g)
        }

        // Systolic peak followed by a smaller dicrotic wave.
        let pulse = gaussian(beatPhase, center: 0.15, width: 0.07)
            + 0.35 * gaussian(beatPhase, center: 0.45, width: 0.08)
        let drift = 0.003 * sin(2 * Double.pi * 0.1 * t)

        if scenario.motionBursts {
            let cycle = t.truncatingRemainder(dividingBy: 7)
            motionOffset = (cycle > 5 && cycle < 5.8) ? 0.04 * rng.nextGaussian() : 0
        }

        let noise = scenario.noise * pulseAmplitude * rng.nextGaussian()
        let red = 0.75 - pulseAmplitude * pulse + drift + noise + motionOffset
        return PulseSample(time: t, red: red, green: 0.12, blue: 0.06)
    }

    public mutating func samples(seconds: Double) -> [PulseSample] {
        (0..<Int(seconds * sampleRate)).map { _ in next() }
    }

    private func gaussian(_ x: Double, center: Double, width: Double) -> Double {
        let d = (x - center) / width
        return exp(-d * d)
    }
}

/// Small deterministic RNG so tests and synthetic runs are repeatable.
public struct SplitMix64: Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in (0, 1).
    public mutating func nextUniform() -> Double {
        (Double(next() >> 11) + 0.5) / Double(1 << 53)
    }

    /// Standard normal (Box–Muller).
    public mutating func nextGaussian() -> Double {
        let u1 = nextUniform(), u2 = nextUniform()
        return sqrt(-2 * log(u1)) * cos(2 * Double.pi * u2)
    }
}
