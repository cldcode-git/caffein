import Foundation
import PulseKit

/// Emits a synthetic fingertip signal at 30 fps. Used on the simulator,
/// which has no camera.
final class SyntheticSignalSource: SignalSource {
    var onSample: ((PulseSample) -> Void)?
    let label: String

    private var generator: SyntheticPulseGenerator
    private let queue = DispatchQueue(label: "vuru.synthetic")
    private var timer: DispatchSourceTimer?

    init(scenario: SyntheticScenario) {
        generator = SyntheticPulseGenerator(scenario: scenario, seed: UInt64.random(in: 1...UInt64.max))
        label = "synthetic:\(scenario.id)"
    }

    func start() async throws {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / generator.sampleRate)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let sample = self.generator.next()
            self.onSample?(sample)
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
