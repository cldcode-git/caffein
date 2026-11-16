import AVFoundation
import PulseKit

/// Back camera + torch. Each frame is reduced to the mean color of its
/// centre, which is all the pulse algorithm needs.
/// All mutable state is touched only on `queue`, hence `@unchecked Sendable`.
final class CameraSignalSource: NSObject, SignalSource, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onSample: ((PulseSample) -> Void)?
    let label = "camera"
    let torchLevel: Float

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "vuru.camera", qos: .userInitiated)
    private var device: AVCaptureDevice?
    private var isConfigured = false

    init(torchLevel: Float) {
        self.torchLevel = torchLevel
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestPermission() async -> Bool {
        switch authorizationStatus {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start() async throws {
        guard await Self.requestPermission() else { throw SignalSourceError.cameraPermissionDenied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning { self.session.startRunning() }
                    // The torch must be switched on after the session starts.
                    try self.setTorch(on: true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            try? self.setTorch(on: false)
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setExposureLocked(_ locked: Bool) {
        queue.async {
            guard let device = self.device else { return }
            let mode: AVCaptureDevice.ExposureMode = locked ? .locked : .continuousAutoExposure
            guard device.isExposureModeSupported(mode), (try? device.lockForConfiguration()) != nil else { return }
            device.exposureMode = mode
            device.unlockForConfiguration()
        }
    }

    // MARK: - Setup (camera queue only)

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw SignalSourceError.cameraUnavailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .low
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw SignalSourceError.cameraConfigurationFailed }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw SignalSourceError.cameraConfigurationFailed }
        session.addOutput(output)

        try device.lockForConfiguration()
        let supports30 = device.activeFormat.videoSupportedFrameRateRanges.contains {
            $0.minFrameRate <= 30 && 30 <= $0.maxFrameRate
        }
        if supports30 {
            let frame = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = frame
            device.activeVideoMaxFrameDuration = frame
        }
        if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
        if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
        device.unlockForConfiguration()

        self.device = device
        isConfigured = true
    }

    private func setTorch(on: Bool) throws {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if on {
            let level = min(max(torchLevel, 0.05), AVCaptureDevice.maxAvailableTorchLevel)
            try device.setTorchModeOn(level: level)
        } else if device.torchMode != .off {
            device.torchMode = .off
        }
    }

    // MARK: - Frames

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        // Centre half of the frame, every 4th pixel in each direction.
        let step = 4
        var r = 0, g = 0, b = 0, count = 0
        var y = height / 4
        while y < height * 3 / 4 {
            let row = pixels + y * bytesPerRow
            var x = width / 4
            while x < width * 3 / 4 {
                let p = row + x * 4 // BGRA
                b += Int(p[0])
                g += Int(p[1])
                r += Int(p[2])
                count += 1
                x += step
            }
            y += step
        }
        guard count > 0 else { return }
        let scale = 1 / (Double(count) * 255)
        onSample?(PulseSample(time: time, red: Double(r) * scale, green: Double(g) * scale, blue: Double(b) * scale))
    }
}
