import Foundation

public enum DrinkCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case coffee, tea, matchaMate, energySoda, other
    public var id: String { rawValue }
}

/// A catalog drink. Display names live in the app (localized by `id`).
public struct Drink: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var category: DrinkCategory
    /// Typical caffeine per serving. Real values vary with brewing and brand.
    public var caffeineMg: Double
    public var symbol: String
    /// App languages (e.g. "tr", "pt") whose users see this drink. Nil means
    /// everyone: international drinks like espresso or cola.
    public var languages: Set<String>?

    public init(id: String, category: DrinkCategory, caffeineMg: Double, symbol: String,
                languages: Set<String>? = nil) {
        self.id = id
        self.category = category
        self.caffeineMg = caffeineMg
        self.symbol = symbol
        self.languages = languages
    }

    public func isAvailable(for language: String) -> Bool {
        languages?.contains(language) ?? true
    }
}

/// Approximate caffeine per serving, rounded, from commonly published
/// reference values (USDA FoodData Central, EFSA, manufacturer labels).
public enum DrinkCatalog {
    public static let all: [Drink] = [
        // Coffee
        Drink(id: "turkishCoffee", category: .coffee, caffeineMg: 60, symbol: "cup.and.saucer.fill", languages: ["tr"]),
        Drink(id: "filterCoffee", category: .coffee, caffeineMg: 95, symbol: "mug.fill"),
        Drink(id: "espresso", category: .coffee, caffeineMg: 63, symbol: "cup.and.saucer.fill"),
        Drink(id: "doubleEspresso", category: .coffee, caffeineMg: 126, symbol: "cup.and.saucer.fill"),
        Drink(id: "americano", category: .coffee, caffeineMg: 126, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "latte", category: .coffee, caffeineMg: 63, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "cappuccino", category: .coffee, caffeineMg: 63, symbol: "cup.and.saucer.fill"),
        Drink(id: "flatWhite", category: .coffee, caffeineMg: 126, symbol: "cup.and.saucer.fill"),
        Drink(id: "cortado", category: .coffee, caffeineMg: 63, symbol: "cup.and.saucer.fill"),
        Drink(id: "mocha", category: .coffee, caffeineMg: 70, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "icedCoffee", category: .coffee, caffeineMg: 90, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "coldBrew", category: .coffee, caffeineMg: 155, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "capsuleEspresso", category: .coffee, caffeineMg: 60, symbol: "capsule.fill"),
        // Same capsule caffeine as espresso, just run with more water.
        Drink(id: "capsuleLungo", category: .coffee, caffeineMg: 60, symbol: "capsule.fill"),
        Drink(id: "frenchPress", category: .coffee, caffeineMg: 100, symbol: "mug.fill"),
        Drink(id: "mokaPot", category: .coffee, caffeineMg: 80, symbol: "cup.and.saucer.fill"),
        Drink(id: "dibekCoffee", category: .coffee, caffeineMg: 50, symbol: "cup.and.saucer.fill", languages: ["tr"]),
        // Light-roast Gulf coffee with cardamom, small finjan.
        Drink(id: "arabicCoffee", category: .coffee, caffeineMg: 40, symbol: "cup.and.saucer.fill", languages: ["ar"]),
        // Small, strong Brazilian coffee (about 50 ml).
        Drink(id: "cafezinho", category: .coffee, caffeineMg: 50, symbol: "cup.and.saucer.fill", languages: ["pt"]),
        Drink(id: "instantCoffee", category: .coffee, caffeineMg: 60, symbol: "mug.fill"),
        Drink(id: "decaf", category: .coffee, caffeineMg: 3, symbol: "mug"),
        // Tea
        Drink(id: "turkishTea", category: .tea, caffeineMg: 30, symbol: "cup.and.saucer.fill", languages: ["tr"]),
        Drink(id: "turkishTeaMug", category: .tea, caffeineMg: 60, symbol: "mug.fill", languages: ["tr"]),
        // Milky spiced black tea as served in South Asia (about 150 ml).
        Drink(id: "masalaChai", category: .tea, caffeineMg: 40, symbol: "cup.and.saucer.fill", languages: ["hi", "bn"]),
        Drink(id: "blackTea", category: .tea, caffeineMg: 47, symbol: "mug.fill"),
        Drink(id: "greenTea", category: .tea, caffeineMg: 28, symbol: "leaf.fill"),
        Drink(id: "whiteTea", category: .tea, caffeineMg: 25, symbol: "leaf"),
        Drink(id: "oolong", category: .tea, caffeineMg: 37, symbol: "mug.fill"),
        Drink(id: "sencha", category: .tea, caffeineMg: 30, symbol: "cup.and.saucer.fill", languages: ["ja"]),
        Drink(id: "chaiLatte", category: .tea, caffeineMg: 70, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "icedTea", category: .tea, caffeineMg: 20, symbol: "waterbottle.fill"),
        // Matcha & mate
        Drink(id: "matcha", category: .matchaMate, caffeineMg: 70, symbol: "leaf.fill"),
        Drink(id: "matchaLatte", category: .matchaMate, caffeineMg: 80, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "mate", category: .matchaMate, caffeineMg: 80, symbol: "leaf.fill", languages: ["es", "pt"]),
        // Energy & soft drinks
        Drink(id: "energySmall", category: .energySoda, caffeineMg: 80, symbol: "bolt.fill"),
        Drink(id: "energyLarge", category: .energySoda, caffeineMg: 160, symbol: "bolt.fill"),
        Drink(id: "cola", category: .energySoda, caffeineMg: 32, symbol: "takeoutbag.and.cup.and.straw.fill"),
        Drink(id: "colaZero", category: .energySoda, caffeineMg: 42, symbol: "takeoutbag.and.cup.and.straw.fill"),
        // Other
        Drink(id: "darkChocolate", category: .other, caffeineMg: 30, symbol: "square.grid.2x2.fill"),
        Drink(id: "caffeineTablet", category: .other, caffeineMg: 100, symbol: "pills.fill"),
    ]

    public static func drink(id: String) -> Drink? {
        all.first { $0.id == id }
    }

    /// Drinks in a category that users of `language` see.
    public static func drinks(in category: DrinkCategory, language: String) -> [Drink] {
        all.filter { $0.category == category && $0.isAvailable(for: language) }
    }

    /// Quick-add buttons: the user's most logged drinks first, then defaults,
    /// all limited to drinks shown for the language.
    public static func quickAdd(recentDrinkIDs: [String], defaults: [String], language: String,
                                count: Int = 5) -> [Drink] {
        var counts: [String: Int] = [:]
        for id in recentDrinkIDs { counts[id, default: 0] += 1 }
        let favourites = counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .compactMap { drink(id: $0.key) }
        var result: [Drink] = []
        for d in favourites + defaults.compactMap(drink(id:))
        where d.isAvailable(for: language) && !result.contains(d) {
            result.append(d)
            if result.count == count { break }
        }
        return result
    }
}
