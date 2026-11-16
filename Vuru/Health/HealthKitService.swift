import HealthKit

/// Writes heart-rate samples to Apple Health. Opt-in from Settings; the
/// app never reads Health data.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let heartRate = HKQuantityType(.heartRate)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var canWrite: Bool {
        isAvailable && store.authorizationStatus(for: heartRate) == .sharingAuthorized
    }

    /// Returns true when the user allowed writing heart rate.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [heartRate], read: [])
        } catch {
            return false
        }
        return canWrite
    }

    func save(bpm: Int, at date: Date) async throws {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let sample = HKQuantitySample(
            type: heartRate,
            quantity: HKQuantity(unit: unit, doubleValue: Double(bpm)),
            start: date,
            end: date,
            metadata: [HKMetadataKeyHeartRateSensorLocation: HKHeartRateSensorLocation.finger.rawValue]
        )
        try await store.save(sample)
    }
}
