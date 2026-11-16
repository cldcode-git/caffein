import Foundation

/// Second-order IIR section (RBJ audio-EQ cookbook formulas).
public struct Biquad: Sendable {
    private let b0, b1, b2, a1, a2: Double
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    public static func lowPass(cutoff: Double, sampleRate: Double, q: Double = 0.7071) -> Biquad {
        let w0 = 2 * Double.pi * cutoff / sampleRate
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        return Biquad(b0: (1 - c) / 2, b1: 1 - c, b2: (1 - c) / 2,
                      a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    public static func highPass(cutoff: Double, sampleRate: Double, q: Double = 0.7071) -> Biquad {
        let w0 = 2 * Double.pi * cutoff / sampleRate
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        return Biquad(b0: (1 + c) / 2, b1: -(1 + c), b2: (1 + c) / 2,
                      a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    public mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }

    /// Sets the internal state as if `input` had been fed forever and the
    /// output had settled at `output`. Avoids a large start-up transient.
    public mutating func prime(input: Double, output: Double) {
        x1 = input; x2 = input
        y1 = output; y2 = output
    }
}

/// Band-pass for the heart-rate band: removes the large constant brightness
/// and slow drift (high-pass) and sensor noise (low-pass).
public struct PulseBandpass: Sendable {
    private var highPass: Biquad
    private var lowPass: Biquad

    public init(sampleRate: Double, lowCutoff: Double = 0.5, highCutoff: Double = 4.0) {
        highPass = .highPass(cutoff: lowCutoff, sampleRate: sampleRate)
        lowPass = .lowPass(cutoff: highCutoff, sampleRate: sampleRate)
    }

    /// Call when a new contiguous signal starts, with its first value.
    public mutating func prime(with value: Double) {
        highPass.prime(input: value, output: 0)
        lowPass.prime(input: 0, output: 0)
    }

    public mutating func process(_ value: Double) -> Double {
        lowPass.process(highPass.process(value))
    }
}
