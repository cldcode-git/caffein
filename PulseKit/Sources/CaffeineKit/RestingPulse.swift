import Foundation

/// What counts as a normal, a bit high or high pulse for one person.
public struct PulseReference: Equatable, Sendable {
    /// The resting pulse expected for someone of this age, sex and weight.
    public var typicalBPM: Int
    /// From this value on, the pulse is a bit high for this person.
    public var elevatedFromBPM: Int
    /// From this value on, the pulse is high for this person.
    public var highFromBPM: Int
    /// False when age and weight are missing and a general adult
    /// reference is used instead.
    public var isPersonal: Bool
}

public enum PulseLevel: Equatable, Sendable {
    case normal
    case elevated
    case high
}

/// A population reference for the resting pulse, adjusted for age, sex and
/// body weight, used to tell whether one measurement is high *for this
/// person*. It is a wellness estimate, not a diagnosis.
///
/// - Typical adult resting pulse in large population surveys is in the low
///   70s; women run about four beats higher than men, adolescents about
///   five beats higher than adults, and people over 65 slightly lower.
/// - Higher body weight goes with a modestly higher resting pulse. Without
///   height we can't use BMI, so weight above a typical weight for the sex
///   adds one beat per 10 kg, at most five.
/// - "A bit high" starts 15 beats above the typical value (roughly the top
///   tenth of the population); "high" starts 25 beats above it and never
///   later than 100 bpm, the usual clinical upper limit for an adult at rest.
public enum RestingPulse {
    public static let elevatedMargin = 15
    public static let highMargin = 25
    public static let clinicalUpperBPM = 100

    public static func reference(for profile: CaffeineProfile?) -> PulseReference {
        guard let p = profile, p.age > 0, p.weightKg > 0 else {
            return make(typical: typicalAdult(.unspecified), isPersonal: false)
        }
        var typical = typicalAdult(p.sex)
        if p.age < CaffeineLimit.adultAge {
            typical += 5
        } else if p.age >= 65 {
            typical -= 2
        }
        let extraKg = p.weightKg - typicalWeightKg(p.sex)
        if extraKg > 0 {
            typical += min(5, Int(extraKg / 10))
        }
        return make(typical: typical, isPersonal: true)
    }

    public static func level(bpm: Int, reference: PulseReference) -> PulseLevel {
        if bpm >= reference.highFromBPM { return .high }
        if bpm >= reference.elevatedFromBPM { return .elevated }
        return .normal
    }

    static func typicalAdult(_ sex: BiologicalSex) -> Int {
        switch sex {
        case .female: 74
        case .male: 70
        case .unspecified: 72
        }
    }

    static func typicalWeightKg(_ sex: BiologicalSex) -> Double {
        switch sex {
        case .female: 65
        case .male: 80
        case .unspecified: 72
        }
    }

    private static func make(typical: Int, isPersonal: Bool) -> PulseReference {
        let elevated = typical + elevatedMargin
        let high = max(elevated + 1, min(clinicalUpperBPM, typical + highMargin))
        return PulseReference(typicalBPM: typical, elevatedFromBPM: elevated,
                              highFromBPM: high, isPersonal: isPersonal)
    }
}
