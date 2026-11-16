import CaffeineKit
import Foundation

/// All user-facing text for data that comes from CaffeineKit.
enum DrinkText {
    static func name(_ id: String) -> String? {
        switch id {
        case "turkishCoffee": L("Türk kahvesi")
        case "filterCoffee": L("Filtre kahve")
        case "espresso": L("Espresso")
        case "doubleEspresso": L("Çift espresso")
        case "americano": L("Americano")
        case "latte": L("Latte")
        case "cappuccino": L("Cappuccino")
        case "flatWhite": L("Flat white")
        case "cortado": L("Cortado / Macchiato")
        case "mocha": L("Mocha")
        case "icedCoffee": L("Buzlu kahve")
        case "coldBrew": L("Cold brew")
        case "capsuleEspresso": L("Kapsül kahve (espresso)")
        // "capsuleMug" is the old ID; past entries now show as lungo too.
        case "capsuleLungo", "capsuleMug": L("Kapsül kahve (lungo)")
        case "frenchPress": L("French press")
        case "mokaPot": L("Moka pot")
        case "dibekCoffee": L("Dibek kahvesi")
        case "arabicCoffee": L("Arap kahvesi (kahve arabi)")
        case "cafezinho": L("Cafezinho")
        case "instantCoffee": L("Hazır kahve")
        case "decaf": L("Kafeinsiz kahve")
        case "turkishTea": L("Demleme çay")
        case "turkishTeaMug": L("Demleme çay (kupa)")
        case "masalaChai": L("Masala chai")
        case "blackTea": L("Siyah çay (poşet)")
        case "greenTea": L("Yeşil çay")
        case "whiteTea": L("Beyaz çay")
        case "oolong": L("Oolong çayı")
        case "sencha": L("Sencha")
        case "chaiLatte": L("Chai latte")
        case "icedTea": L("Soğuk çay")
        case "matcha": L("Matcha")
        case "matchaLatte": L("Matcha latte")
        case "mate": L("Mate")
        case "energySmall": L("Enerji içeceği")
        case "energyLarge": L("Enerji içeceği (büyük)")
        case "cola": L("Kola")
        case "colaZero": L("Kola (şekersiz)")
        case "darkChocolate": L("Bitter çikolata")
        case "caffeineTablet": L("Kafein tableti")
        default: nil
        }
    }

    static func serving(_ id: String) -> String {
        switch id {
        case "turkishCoffee", "dibekCoffee", "sencha", "mokaPot": L("1 fincan")
        case "filterCoffee", "frenchPress", "blackTea", "greenTea", "whiteTea", "oolong", "mate": L("1 kupa (240 ml)")
        case "espresso", "latte", "cappuccino", "cortado", "mocha": L("tek shot")
        case "doubleEspresso", "americano", "flatWhite": L("çift shot")
        case "icedCoffee", "coldBrew", "chaiLatte", "matchaLatte": L("orta boy")
        case "capsuleEspresso": L("1 kapsül, 40 ml")
        case "capsuleLungo": L("1 kapsül, 110 ml")
        case "instantCoffee", "decaf", "turkishTeaMug": L("1 kupa")
        case "turkishTea": L("1 ince belli bardak")
        case "arabicCoffee": L("1 küçük fincan (finjan)")
        case "cafezinho": L("1 küçük fincan (50 ml)")
        case "masalaChai": L("1 bardak (150 ml)")
        case "icedTea", "cola", "colaZero": L("330 ml")
        case "matcha": L("1 çay kaşığı (2 g)")
        case "energySmall": L("250 ml kutu")
        case "energyLarge": L("500 ml kutu")
        case "darkChocolate": L("40 g")
        case "caffeineTablet": L("1 tablet")
        default: ""
        }
    }

    static func category(_ category: DrinkCategory) -> String {
        switch category {
        case .coffee: L("Kahveler")
        case .tea: L("Çaylar")
        case .matchaMate:
            DrinkCatalog.drinks(in: .matchaMate, language: AppLanguage.current.resolvedCode).contains { $0.id == "mate" }
                ? L("Matcha ve mate") : L("Matcha")
        case .energySoda: L("Enerji ve gazlı içecekler")
        case .other: L("Diğer")
        }
    }

    static func displayName(_ intake: CaffeineIntake) -> String {
        name(intake.drinkID) ?? intake.name
    }

/// Quick-add defaults before the user has favourites, per language.
/// Drinks not shown for the language are skipped by the catalog.
static var defaultQuickAdd: [String] {
    switch AppLanguage.current.resolvedCode {
    case "tr": ["turkishCoffee", "turkishTea", "filterCoffee", "espresso", "latte"]
    case "ar": ["arabicCoffee", "espresso", "cappuccino", "blackTea", "latte"]
    case "hi", "bn": ["masalaChai", "instantCoffee", "filterCoffee", "greenTea", "cola"]
    case "pt": ["cafezinho", "espresso", "filterCoffee", "mate", "capsuleEspresso"]
    case "es": ["espresso", "cortado", "americano", "mate", "latte"]
    case "ja", "zh-Hans": ["greenTea", "matcha", "americano", "latte", "blackTea"]
    case "ru", "de", "fr": ["filterCoffee", "espresso", "cappuccino", "blackTea", "capsuleEspresso"]
    default: ["filterCoffee", "espresso", "latte", "capsuleEspresso", "blackTea"]
    }
}
}

enum StressText {
    static func title(_ level: StressLevel) -> String {
        switch level {
        case .low: L("Sakin")
        case .moderate: L("Orta")
        case .high: L("Yüksek")
        }
    }
}

enum InsightText {
    static func title(_ insight: Insight) -> String {
        switch insight {
        case .lateCaffeineHurtsSleep: L("Geç kafein uykunu etkiliyor olabilir")
        case .sleepResilient: L("Uykun geç kafeine dayanıklı görünüyor")
        case .lateCaffeineShortensSleep: L("Geç kafein uykunu kısaltıyor olabilir")
        case .heavyDaysRaiseMorningHR: L("Yoğun kafein günlerinin ertesi sabahı nabzın daha yüksek")
        case .caffeineRaisesTension: L("Kafeinli günlerde daha gergin hissediyorsun")
        case .caffeineNotLinkedToTension: L("Kafein gerginliğini artırmıyor gibi görünüyor")
        case .breathingHelps: L("Nefes egzersizi sana iyi geliyor")
        case .breathingNeutral: L("Nefes egzersizi nabzını pek değiştirmedi")
        case .lateNights: L("Son kahveni biraz öne almayı dene")
        case .balancedTiming: L("Kafein saatlerin dengeli")
        }
    }

    static func detail(_ insight: Insight) -> String {
        let threshold = CaffeineModel.sleepThresholdMg.mgText
        switch insight {
        case .lateCaffeineHurtsSleep(let nights, let drop):
            return L("Yatarken vücudunda \(threshold)'den fazla kafein kalan \(nights) gecede uyku puanın ortalama \(drop.oneDecimal) puan daha düşüktü.")
        case .sleepResilient:
            return L("Yatarken vücudunda kafein kalan gecelerle kalmayan geceler arasında uyku puanında belirgin bir fark yok.")
        case .lateCaffeineShortensSleep(let nights, let minutes):
            return L("Yatarken vücudunda \(threshold)'den fazla kafein kalan \(nights) gecede ortalama \(durationText(minutes: minutes)) daha az uyudun.")
        case .heavyDaysRaiseMorningHR(let mg, let bpm):
            return L("\(mg.mgText) üzerinde kafein aldığın günlerin ertesi sabahı dinlenme nabzın ortalama \(Int(bpm.rounded())) atım daha yüksekti.")
        case .caffeineRaisesTension(let mg, let increase):
            return L("\(mg.mgText) üzerinde kafein aldığın günlerde gerginlik puanın ortalama \(increase.oneDecimal) puan daha yüksekti.")
        case .caffeineNotLinkedToTension:
            return L("Daha çok kafein aldığın günlerde gerginlik puanın daha yüksek değildi.")
        case .breathingHelps(let sessions, let drop):
            return L("\(sessions) nefes egzersizinin ardından nabzın ortalama \(Int(drop.rounded())) atım yavaşladı.")
        case .breathingNeutral:
            return L("Yine de iyi hissettiriyorsa sürdürmeye değer; farklı saatlerde denemeyi düşünebilirsin.")
        case .lateNights(let late, let total):
            return L("\(total) gecenin \(late) tanesinde yatarken vücudunda \(threshold)'den fazla kafein vardı.")
        case .balancedTiming:
            return L("Kayıtlı gecelerin hiçbirinde yatarken vücudunda belirgin kafein kalmadı.")
        }
    }
}
