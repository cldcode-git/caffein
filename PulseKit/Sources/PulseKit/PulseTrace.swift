import Foundation

/// A recorded measurement attempt: raw samples plus what the app concluded.
/// QA builds save these so accuracy can be checked against a reference
/// device and old recordings can be re-analysed after algorithm changes.
public struct PulseTrace: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var device: String
    public var source: String
    public var torchLevel: Double?
    /// Heart rate read from a reference (watch, oximeter, manual count).
    public var referenceBPM: Int?
    public var result: PulseResult?
    public var note: String?
    public var samples: [PulseSample]

    public init(id: UUID = UUID(), createdAt: Date = Date(), device: String, source: String,
                torchLevel: Double? = nil, referenceBPM: Int? = nil, result: PulseResult? = nil,
                note: String? = nil, samples: [PulseSample]) {
        self.id = id
        self.createdAt = createdAt
        self.device = device
        self.source = source
        self.torchLevel = torchLevel
        self.referenceBPM = referenceBPM
        self.result = result
        self.note = note
        self.samples = samples
    }

    /// Absolute error against the reference, when both exist.
    public var error: Int? {
        guard let ref = referenceBPM, let bpm = result?.bpm else { return nil }
        return abs(bpm - ref)
    }

    /// Effective frame rate of the recording.
    public var sampleRate: Double? {
        guard samples.count > 1, let first = samples.first, let last = samples.last,
              last.time > first.time else { return nil }
        return Double(samples.count - 1) / (last.time - first.time)
    }

    /// One row per sample: time from start and the three channel means.
    public func samplesCSV() -> String {
        let t0 = samples.first?.time ?? 0
        var lines = ["t,red,green,blue"]
        lines.reserveCapacity(samples.count + 1)
        for s in samples {
            lines.append(String(format: "%.4f,%.6f,%.6f,%.6f", s.time - t0, s.red, s.green, s.blue))
        }
        return lines.joined(separator: "\n")
    }

    /// Summary table over many traces, for a spreadsheet.
    public static func summaryCSV(_ traces: [PulseTrace]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["id,date,device,source,torch,fps,reference_bpm,app_bpm,abs_error,quality,beat_bpm,spectral_bpm,prominence,consistent_ratio,note"]
        func f(_ v: Double?, _ digits: Int = 1) -> String {
            v.map { String(format: "%.\(digits)f", $0) } ?? ""
        }
        for t in traces {
            let r = t.result
            let note = (t.note ?? "").replacingOccurrences(of: ",", with: ";")
            lines.append([
                t.id.uuidString, iso.string(from: t.createdAt), t.device, t.source,
                f(t.torchLevel, 2), f(t.sampleRate), t.referenceBPM.map(String.init) ?? "",
                r.map { String($0.bpm) } ?? "", t.error.map(String.init) ?? "",
                r?.quality.rawValue ?? "failed", f(r?.beatBPM), f(r?.spectralBPM),
                f(r?.spectralProminence), f(r?.consistentIntervalRatio, 2), note,
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
