import Foundation
import SwiftData

@Model
final class CaffeineIntake {
    var date: Date
    var drinkID: String
    var name: String
    /// Caffeine in one serving.
    var caffeineMg: Double
    var symbol: String
    /// How many servings were drunk at `date`. Records made before this
    /// field existed get 1.
    var servings: Int = 1

    init(date: Date = Date(), drinkID: String, name: String, caffeineMg: Double, symbol: String,
         servings: Int = 1) {
        self.date = date
        self.drinkID = drinkID
        self.name = name
        self.caffeineMg = caffeineMg
        self.symbol = symbol
        self.servings = servings
    }

    /// Caffeine in all servings together.
    var totalMg: Double { caffeineMg * Double(max(1, servings)) }
}

enum PulseKind: String, Codable {
    /// Resting measurement right after waking. Builds the personal normal.
    case morning
    case tenseBefore
    case tenseAfter
}

@Model
final class PulseReading {
    var date: Date
    var bpm: Int
    var kindRaw: String
    var qualityRaw: String
    /// Links the before/after readings of one breathing session.
    var sessionID: UUID?

    init(date: Date = Date(), bpm: Int, kind: PulseKind, quality: String, sessionID: UUID? = nil) {
        self.date = date
        self.bpm = bpm
        self.kindRaw = kind.rawValue
        self.qualityRaw = quality
        self.sessionID = sessionID
    }

    var kind: PulseKind { PulseKind(rawValue: kindRaw) ?? .morning }
}

/// The two morning questions about last night.
@Model
final class SleepLog {
    /// When the answers were given (the morning).
    var date: Date
    var bedtime: Date
    /// When the user woke up. Optional so older records still load.
    var wakeTime: Date?
    /// 1 (very bad) ... 5 (very good)
    var quality: Int

    init(date: Date = Date(), bedtime: Date, wakeTime: Date?, quality: Int) {
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.quality = quality
    }

    /// Minutes asleep, when both times are known and plausible.
    var sleepMinutes: Double? {
        guard let wakeTime else { return nil }
        let minutes = wakeTime.timeIntervalSince(bedtime) / 60
        return (60...(16 * 60)).contains(minutes) ? minutes : nil
    }
}

/// Evening rating of how tense the day felt, 1 ... 5.
@Model
final class TensionRating {
    var day: Date
    var score: Int

    init(day: Date, score: Int) {
        self.day = day
        self.score = score
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        CaffeineIntake.self, PulseReading.self, SleepLog.self, TensionRating.self,
    ]
}

enum SleepQuality {
    static func title(_ value: Int) -> String {
        switch min(max(value, 1), 5) {
        case 1: L("Çok kötü")
        case 2: L("Kötü")
        case 3: L("İdare eder")
        case 4: L("İyi")
        default: L("Çok iyi")
        }
    }
}

enum TensionScale {
    static func title(_ value: Int) -> String {
        switch min(max(value, 1), 5) {
        case 1: L("Çok sakin")
        case 2: L("Sakin")
        case 3: L("Orta")
        case 4: L("Gergin")
        default: L("Çok gergin")
        }
    }
}
