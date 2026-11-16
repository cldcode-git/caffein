import CoreMotion
import UIKit

/// A soft tap on every detected beat.
@MainActor
final class BeatHaptics {
    private let generator = UIImpactFeedbackGenerator(style: .soft)

    func prepare() {
        generator.prepare()
    }

    func beat() {
        generator.impactOccurred(intensity: 0.7)
        generator.prepare()
    }
}

/// Reports whether the phone is being moved, which ruins the camera signal.
@MainActor
final class MotionMonitor {
    private let manager = CMMotionManager()
    private var lastMovement: Date = .distantPast

    /// `handler` runs on the main queue with true while the phone moves.
    func start(_ handler: @escaping (Bool) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let a = motion?.userAcceleration else { return }
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            if magnitude > 0.08 { self.lastMovement = Date() }
            // Keep the warning up for a second after movement stops.
            handler(Date().timeIntervalSince(self.lastMovement) < 1)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
