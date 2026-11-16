import PulseKit
import SwiftUI

/// Camera pulse measurement used inside the morning and "Gerginim" flows.
/// Starts as soon as it appears; calls `onResult` once with a usable reading.
struct PulseMeasurementView: View {
    let duration: TimeInterval
    var instruction: String
    var onResult: (PulseResult) -> Void
    /// Offered after a failed measurement, to continue without a number.
    var onSkip: (() -> Void)?

    @State private var model: PulseMeasurementModel
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase

    init(duration: TimeInterval, instruction: String,
         onResult: @escaping (PulseResult) -> Void, onSkip: (() -> Void)? = nil) {
        self.duration = duration
        self.instruction = instruction
        self.onResult = onResult
        self.onSkip = onSkip
        _model = State(initialValue: PulseMeasurementModel(duration: duration))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            PulseRing(progress: progress, beatTick: model.beatTick, isActive: isFingerOn, tint: Theme.alert) {
                ringCenter
            }
            .frame(width: 240, height: 240)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(model.isMoving && isFingerOn ? Theme.alert : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40, alignment: .top)
            }
            .padding(.horizontal, 28)

            actions

            WaveformView(values: model.waveform, capacity: PulseMeasurementModel.waveformCapacity, tint: Theme.alert)
                .frame(height: 52)
                .padding(.horizontal, 24)
                .opacity(isFingerOn ? 1 : 0)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.status == .paused { Task { await model.start() } }
        }
        .onAppear {
            isVisible = true
            Task { await model.start() }
        }
        .onDisappear {
            isVisible = false
            model.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // The camera permission alert makes the scene briefly inactive,
            // so only react to background/active.
            if newPhase == .active, isVisible {
                Task { await model.start() }
            } else if newPhase == .background {
                model.stop()
            }
        }
        .onChange(of: model.status) { _, status in
            if case .done(let result) = status { onResult(result) }
        }
    }

    // MARK: - Derived state

    private var isFingerOn: Bool {
        switch model.phase {
        case .settling, .measuring: true
        default: false
        }
    }

    private var progress: Double {
        if case .done = model.status { return 1 }
        if case .measuring(let p) = model.phase { return p }
        return 0
    }

    @ViewBuilder
    private var ringCenter: some View {
        if case .done(let r) = model.status {
            bpmText(r.bpm)
        } else if case .failed = model.status {
            Image(systemName: "waveform.path.badge.minus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
        } else {
            switch model.phase {
            case .measuring:
                if let bpm = model.liveBPM {
                    bpmText(bpm)
                } else {
                    ProgressView().controlSize(.large)
                }
            case .settling:
                ProgressView().controlSize(.large)
            default:
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.alert)
                    .symbolEffect(.pulse, isActive: model.status == .running)
            }
        }
    }

    private func bpmText(_ bpm: Int) -> some View {
        VStack(spacing: 0) {
            Text(String(bpm))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: bpm)
            Text("BPM")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dakikada \(bpm) atım")
    }

    private var title: String {
        switch model.status {
        case .needsPermission: return L("Kamera izni gerekli")
        case .unavailable: return L("Ölçüm başlatılamadı")
        case .paused: return L("Duraklatıldı")
        case .failed: return L("Güvenilir bir ölçüm alınamadı")
        case .done: return L("Ölçüm tamam")
        case .idle: return L("Hazırlanıyor")
        case .running: break
        }
        switch model.phase {
        case .noFinger: return L("Parmağını arka kameraya koy")
        case .settling: return L("Sinyal aranıyor")
        case .measuring: return L("Ölçülüyor")
        case .finished, .failed: return L("Değerlendiriliyor")
        }
    }

    private var hint: String {
        switch model.status {
        case .needsPermission:
            return L("Nabzını parmak ucundaki renk değişiminden okuyoruz. Görüntü kaydedilmez.")
        case .unavailable(let message):
            return message
        case .paused:
            return L("Pil tasarrufu için durdu. Devam etmek için dokun.")
        case .failed:
            return L("Sinyal zayıf olduğu için sayı göstermiyoruz. Elini ısıtıp, parmağını bastırmadan tekrar dene.")
        case .done(let r):
            return r.quality == .fair ? L("Sinyal tam net değildi; sonuç birkaç atım sapabilir.") : ""
        case .idle, .running:
            break
        }
        if model.isMoving && isFingerOn { return L("Telefonu sabit tut") }
        switch model.phase {
        case .noFinger:
            return model.retryHint ?? instruction
        case .settling:
            return L("Kıpırdamadan bekle")
        case .measuring(let p):
            let remaining = max(1, Int(((1 - p) * duration).rounded(.up)))
            return L("Yaklaşık \(remaining) sn kaldı")
        case .finished, .failed:
            return ""
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch model.status {
        case .needsPermission:
            Button("Ayarları aç") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        case .unavailable, .paused:
            Button("Tekrar dene") { Task { await model.start() } }
                .buttonStyle(.bordered)
        case .failed:
            HStack(spacing: 12) {
                Button("Tekrar ölç") { Task { await model.retry() } }
                    .buttonStyle(.borderedProminent)
                if let onSkip {
                    Button("Ölçümsüz devam et", action: onSkip)
                        .buttonStyle(.bordered)
                }
            }
        default:
            EmptyView()
        }
    }
}
