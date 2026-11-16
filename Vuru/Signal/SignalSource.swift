import Foundation
import PulseKit

/// Anything that produces fingertip color samples: the real camera, a
/// synthetic generator (simulator/QA), or a replay of a recorded trace.
protocol SignalSource: AnyObject {
    /// Called on a background queue for every sample.
    var onSample: ((PulseSample) -> Void)? { get set }
    var label: String { get }
    func start() async throws
    func stop()
    /// Exposure must stay fixed while measuring, or auto-exposure will
    /// flatten the pulse. Only the camera does anything here.
    func setExposureLocked(_ locked: Bool)
}

extension SignalSource {
    func setExposureLocked(_ locked: Bool) {}
}

enum SignalSourceError: LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case cameraConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied: L("Kamera izni verilmedi.")
        case .cameraUnavailable: L("Bu cihazda arka kamera bulunamadı.")
        case .cameraConfigurationFailed: L("Kamera başlatılamadı.")
        }
    }
}

enum SignalSourceFactory {
    /// Torch brightness for the camera measurement.
    static let torchLevel: Float = 0.6

    /// The real camera on a phone. The simulator has no camera, so it
    /// gets a synthetic resting pulse instead.
    @MainActor
    static func make() -> SignalSource {
        #if targetEnvironment(simulator)
        return SyntheticSignalSource(scenario: .resting)
        #else
        return CameraSignalSource(torchLevel: torchLevel)
        #endif
    }
}
