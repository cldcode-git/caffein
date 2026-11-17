import CaffeineKit
import Foundation

enum SettingsKey {
    static let didOnboard = "didOnboard"
    static let hapticsEnabled = "hapticsEnabled"
    static let healthSyncEnabled = "healthSyncEnabled"

    /// Usual bedtime as minutes after midnight (e.g. 23:30 → 1410).
    static let bedtimeMinutes = "bedtimeMinutes"
    static let sensitivity = "caffeineSensitivity"
    /// 0 until the user enters it.
    static let profileAge = "profileAge"
    /// Kilograms; 0 until the user enters it.
    static let profileWeight = "profileWeight"
    static let pregnant = "pregnantOrBreastfeeding"
    /// A `BiologicalSex` raw value; "unspecified" until the user chooses.
    static let sex = "profileSex"
    static let morningReminder = "morningReminder"
    static let morningReminderMinutes = "morningReminderMinutes"
    static let weeklyReminder = "weeklyReminder"

}

enum AppDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.hapticsEnabled: true,
            SettingsKey.healthSyncEnabled: false,
            SettingsKey.bedtimeMinutes: 23 * 60,
            SettingsKey.profileAge: 0,
            SettingsKey.profileWeight: 0.0,
            SettingsKey.pregnant: false,
            SettingsKey.sex: BiologicalSex.unspecified.rawValue,
            SettingsKey.sensitivity: CaffeineSensitivity.normal.rawValue,
            SettingsKey.morningReminder: false,
            SettingsKey.morningReminderMinutes: 7 * 60 + 30,
            SettingsKey.weeklyReminder: false,
        ])
    }
}

/// Settings that shape the caffeine maths, read in one place.
struct CaffeinePreferences {
    var bedtimeMinutes: Int
    var sensitivity: CaffeineSensitivity
    /// Nil until age and weight are entered.
    var profile: CaffeineProfile?

    static var current: CaffeinePreferences {
        let d = UserDefaults.standard
        return CaffeinePreferences(
            bedtimeMinutes: d.integer(forKey: SettingsKey.bedtimeMinutes),
            sensitivity: CaffeineSensitivity(rawValue: d.string(forKey: SettingsKey.sensitivity) ?? "") ?? .normal,
            profile: profile(age: d.integer(forKey: SettingsKey.profileAge),
                             weight: d.double(forKey: SettingsKey.profileWeight),
                             pregnant: d.bool(forKey: SettingsKey.pregnant),
                             sex: BiologicalSex(rawValue: d.string(forKey: SettingsKey.sex) ?? "") ?? .unspecified)
        )
    }

    /// Sex doesn't change the caffeine limit, so screens that only show the
    /// limit can leave it out.
    static func profile(age: Int, weight: Double, pregnant: Bool,
                        sex: BiologicalSex = .unspecified) -> CaffeineProfile? {
        guard age > 0, weight > 0 else { return nil }
        return CaffeineProfile(age: age, weightKg: weight, pregnantOrBreastfeeding: pregnant, sex: sex)
    }

    var model: CaffeineModel { CaffeineModel(sensitivity: sensitivity) }
    var limit: CaffeineLimit.Result { CaffeineLimit.daily(for: profile) }
    var dailyLimitMg: Double { limit.dailyMg }
}

/// The app's notion of a "day" runs from 04:00 to 04:00, so a late-night
/// tea still belongs to the evening before.
enum DayClock {
    static let dayStartHour = 4
    static var calendar: Calendar { Calendar.current }

    static func dayStart(for date: Date) -> Date {
        let shifted = date.addingTimeInterval(-Double(dayStartHour) * 3600)
        let midnight = calendar.startOfDay(for: shifted)
        return midnight.addingTimeInterval(Double(dayStartHour) * 3600)
    }

    static func nextDayStart(after dayStart: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
    }

    /// Planned bedtime for the night that ends the given day.
    static func bedtime(forDayStarting dayStart: Date, minutes: Int) -> Date {
        let midnight = calendar.startOfDay(for: dayStart)
        // Times before noon (e.g. 00:30) belong to the next calendar day.
        let dayOffset = minutes < 12 * 60 ? 1 : 0
        let day = calendar.date(byAdding: .day, value: dayOffset, to: midnight) ?? midnight
        return day.addingTimeInterval(Double(minutes) * 60)
    }

    static func date(from minutes: Int, on day: Date = Date()) -> Date {
        calendar.startOfDay(for: day).addingTimeInterval(Double(minutes) * 60)
    }

    static func minutes(from date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

enum BuildInfo {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }


    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

}

enum AppLinks {
    // TODO: Faz 5'te gerçek adreslerle değiştir.
    static let privacyPolicy = URL(string: "https://example.com/caffein/gizlilik")!
    static let support = URL(string: "https://example.com/caffein/destek")!

    /// Emergency number for the current region (112 works across Europe and Türkiye).
    static var emergencyNumber: String {
        switch Locale.current.region?.identifier {
        case "US", "CA", "MX": "911"
        default: "112"
        }
    }
}
