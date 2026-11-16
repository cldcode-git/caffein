import XCTest
@testable import CaffeineKit

final class CaffeineModelTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let model = CaffeineModel()

    func testNothingBeforeDrinking() {
        let dose = CaffeineDose(time: t0, milligrams: 100)
        XCTAssertEqual(model.amount(of: dose, at: t0.addingTimeInterval(-60)), 0)
        XCTAssertEqual(model.amount(of: dose, at: t0), 0)
    }

    func testPeaksAroundFortyFiveMinutes() {
        let dose = CaffeineDose(time: t0, milligrams: 100)
        let curve = model.curve([dose], from: t0, to: t0.addingTimeInterval(4 * 3600), step: 60)
        let peak = curve.max { $0.milligrams < $1.milligrams }!
        let minutes = peak.time.timeIntervalSince(t0) / 60
        XCTAssertEqual(minutes, 45, accuracy: 10)
        XCTAssertGreaterThan(peak.milligrams, 85)
        XCTAssertLessThanOrEqual(peak.milligrams, 100)
    }

    func testHalvesEveryHalfLifeAfterAbsorption() {
        let dose = CaffeineDose(time: t0, milligrams: 200)
        let at3h = model.amount(of: dose, at: t0.addingTimeInterval(3 * 3600))
        let at8h = model.amount(of: dose, at: t0.addingTimeInterval(8 * 3600))
        XCTAssertEqual(at8h / at3h, 0.5, accuracy: 0.01)
    }

    func testSlowMetabolismKeepsMoreCaffeine() {
        let dose = CaffeineDose(time: t0, milligrams: 100)
        let later = t0.addingTimeInterval(8 * 3600)
        let slow = CaffeineModel(sensitivity: .slow).amount(of: dose, at: later)
        let fast = CaffeineModel(sensitivity: .fast).amount(of: dose, at: later)
        XCTAssertGreaterThan(slow, fast * 1.8)
    }

    func testLevelsAddUp() {
        let a = CaffeineDose(time: t0, milligrams: 60)
        let b = CaffeineDose(time: t0.addingTimeInterval(3600), milligrams: 30)
        let t = t0.addingTimeInterval(3 * 3600)
        XCTAssertEqual(model.level([a, b], at: t), model.amount(of: a, at: t) + model.amount(of: b, at: t), accuracy: 1e-9)
    }

    func testLatestIntakeTimeRespectsThreshold() {
        let bedtime = t0.addingTimeInterval(16 * 3600) // 16 h after t0
        let latest = model.latestIntakeTime(existing: [], nextDoseMg: 95, bedtime: bedtime, earliest: t0)!
        let hoursBeforeBed = bedtime.timeIntervalSince(latest) / 3600
        // 95 mg must fall to ≤ 30 mg: about 1.7 half-lives (8.3 h) plus absorption.
        XCTAssertEqual(hoursBeforeBed, 8.5, accuracy: 1)
        let level = model.peakDuringSleep([CaffeineDose(time: latest, milligrams: 95)], bedtime: bedtime)
        XCTAssertLessThanOrEqual(level, CaffeineModel.sleepThresholdMg)
        // 15 minutes later would be too late.
        let tooLate = model.peakDuringSleep([CaffeineDose(time: latest.addingTimeInterval(900), milligrams: 95)], bedtime: bedtime)
        XCTAssertGreaterThan(tooLate, CaffeineModel.sleepThresholdMg)
    }

    func testEarlierCaffeinePushesCutoffEarlier() {
        let bedtime = t0.addingTimeInterval(16 * 3600)
        let none = model.latestIntakeTime(existing: [], nextDoseMg: 60, bedtime: bedtime, earliest: t0)!
        let morning = [CaffeineDose(time: t0.addingTimeInterval(2 * 3600), milligrams: 200)]
        let some = model.latestIntakeTime(existing: morning, nextDoseMg: 60, bedtime: bedtime, earliest: t0)!
        XCTAssertLessThan(some, none)
    }

    func testNoMoreCaffeineWhenAlreadyOverThreshold() {
        let bedtime = t0.addingTimeInterval(4 * 3600)
        let heavy = [CaffeineDose(time: t0, milligrams: 300)]
        XCTAssertNil(model.latestIntakeTime(existing: heavy, nextDoseMg: 60, bedtime: bedtime, earliest: t0))
    }

    func testTimeWhenBelow() {
        let dose = CaffeineDose(time: t0, milligrams: 200)
        let when = model.timeWhenBelow(50, doses: [dose], after: t0)!
        XCTAssertLessThan(model.level([dose], at: when), 50)
        XCTAssertEqual(when.timeIntervalSince(t0) / 3600, 10.5, accuracy: 1)
    }
}

final class DrinkCatalogTests: XCTestCase {
    func testIDsAreUnique() {
        XCTAssertEqual(Set(DrinkCatalog.all.map(\.id)).count, DrinkCatalog.all.count)
    }

    func testCategoriesAndRemovedDrinks() {
        XCTAssertNil(DrinkCatalog.drink(id: "instant3in1"))
        XCTAssertEqual(DrinkCatalog.drink(id: "capsuleEspresso")?.category, .coffee)
        XCTAssertNil(DrinkCatalog.drink(id: "capsuleMug"))
        XCTAssertEqual(DrinkCatalog.drink(id: "capsuleLungo")?.caffeineMg,
                       DrinkCatalog.drink(id: "capsuleEspresso")?.caffeineMg)
        XCTAssertEqual(DrinkCatalog.drink(id: "matcha")?.category, .matchaMate)
        XCTAssertGreaterThanOrEqual(DrinkCatalog.drinks(in: .coffee, language: "en").count, 15)
        for category in DrinkCategory.allCases {
            XCTAssertFalse(DrinkCatalog.drinks(in: category, language: "en").isEmpty, category.rawValue)
        }
    }

    func testRegionalDrinksFollowLanguage() {
        let en = Set(DrinkCategory.allCases.flatMap { DrinkCatalog.drinks(in: $0, language: "en") }.map(\.id))
        let tr = Set(DrinkCategory.allCases.flatMap { DrinkCatalog.drinks(in: $0, language: "tr") }.map(\.id))
        for id in ["turkishCoffee", "turkishTea", "turkishTeaMug", "dibekCoffee", "mate", "sencha", "arabicCoffee"] {
            XCTAssertFalse(en.contains(id), id)
        }
        XCTAssertTrue(tr.isSuperset(of: ["turkishCoffee", "turkishTea", "dibekCoffee"]))
        XCTAssertFalse(tr.contains("mate"))
        XCTAssertTrue(en.isSuperset(of: ["espresso", "filterCoffee", "capsuleLungo", "matcha", "cola"]))
        XCTAssertTrue(DrinkCatalog.drinks(in: .matchaMate, language: "es").contains { $0.id == "mate" })
        XCTAssertTrue(DrinkCatalog.drinks(in: .tea, language: "hi").contains { $0.id == "masalaChai" })
    }

    func testQuickAddPutsFavouritesFirst() {
        let quick = DrinkCatalog.quickAdd(recentDrinkIDs: ["mate", "espresso", "mate"],
                                          defaults: ["turkishCoffee", "turkishTea", "espresso", "latte", "filterCoffee"],
                                          language: "es")
        XCTAssertEqual(quick.map(\.id).prefix(2), ["mate", "espresso"])
        XCTAssertEqual(Set(quick.map(\.id)).count, quick.count)
        XCTAssertFalse(quick.contains { $0.id == "turkishCoffee" })
    }

    func testQuickAddHidesOtherLanguagesDrinks() {
        let quick = DrinkCatalog.quickAdd(recentDrinkIDs: ["turkishCoffee", "turkishCoffee", "latte"],
                                          defaults: ["filterCoffee", "espresso", "latte", "capsuleEspresso", "blackTea"],
                                          language: "en")
        XCTAssertEqual(quick.first?.id, "latte")
        XCTAssertEqual(quick.count, 5)
        XCTAssertFalse(quick.contains { $0.id == "turkishCoffee" })
    }
}

final class StressIndexTests: XCTestCase {
    func testNeedsFiveMornings() {
        XCTAssertNil(StressIndex.baseline(morningBPMs: [60, 61, 62, 63]))
        XCTAssertNotNil(StressIndex.baseline(morningBPMs: [60, 61, 62, 63, 64]))
    }

    func testBaselineIsRobustToOutliers() {
        let b = StressIndex.baseline(morningBPMs: [60, 61, 59, 60, 95, 61, 60])!
        XCTAssertEqual(b.median, 60, accuracy: 0.5)
        XCTAssertEqual(b.spread, 3) // floor
    }

    func testElevatedPulseAndTensionIsHigh() {
        let b = HeartBaseline(median: 60, spread: 3, sampleCount: 10)
        let a = StressIndex.assess(morningBPM: 70, baseline: b, tensionScore: 5)!
        XCTAssertEqual(a.level, .high)
        XCTAssertEqual(a.heartRateDeviation, 10)
    }

    func testNormalPulseAndLowTensionIsCalm() {
        let b = HeartBaseline(median: 60, spread: 3, sampleCount: 10)
        XCTAssertEqual(StressIndex.assess(morningBPM: 59, baseline: b, tensionScore: 1)?.level, .low)
    }

    func testWorksWithTensionOnly() {
        XCTAssertEqual(StressIndex.assess(morningBPM: 70, baseline: nil, tensionScore: 3)?.level, .moderate)
        XCTAssertNil(StressIndex.assess(morningBPM: nil, baseline: nil, tensionScore: nil))
    }
}

final class InsightTests: XCTestCase {
    private func days(count: Int, make: (Int) -> DaySummary) -> [DaySummary] {
        (0..<count).map(make)
    }

    func testNoInsightsWithFewDays() {
        let d = days(count: 4) { _ in DaySummary(day: Date(), caffeineMg: 200, sleepQuality: 3) }
        XCTAssertTrue(InsightEngine.insights(d).isEmpty)
    }

    func testLateCaffeineWorseSleep() {
        let d = days(count: 10) { i in
            let late = i.isMultiple(of: 2)
            return DaySummary(day: Date(), caffeineMg: late ? 300 : 120,
                              bedtimeLevelMg: late ? 90 : 20, sleepQuality: late ? 2 : 4)
        }
        let insights = InsightEngine.insights(d)
        XCTAssertTrue(insights.contains { if case .lateCaffeineHurtsSleep = $0 { true } else { false } })
        XCTAssertNotNil(insights.first { $0.id == "habit" })
    }

    func testHeartInsightNeedsRealDifference() {
        let similar = days(count: 10) { i in
            DaySummary(day: Date(), caffeineMg: Double(100 + i * 30), nextMorningBPM: 60 + Double(i % 2))
        }
        XCTAssertNil(InsightEngine.heartInsight(similar))
        let different = days(count: 10) { i in
            DaySummary(day: Date(), caffeineMg: Double(100 + i * 30), nextMorningBPM: i >= 5 ? 68 : 60)
        }
        XCTAssertNotNil(InsightEngine.heartInsight(different))
    }

    func testWeeklySummary() {
        let d = days(count: 7) { i in
            DaySummary(day: Date(), caffeineMg: i == 0 ? 450 : 200, bedtimeLevelMg: i < 2 ? 80 : 10,
                       sleepQuality: 4, tension: 2)
        }
        let s = WeeklySummary.make(d, dailyLimitMg: 400)
        XCTAssertEqual(s.totalMg, 1650)
        XCTAssertEqual(s.daysOverLimit, 1)
        XCTAssertEqual(s.lateNights, 2)
        XCTAssertEqual(s.averageSleepQuality, 4)
    }
}

final class SleepTests: XCTestCase {
    /// Days above 250 mg lose about an hour of sleep.
    private func history(count: Int = 14) -> [DaySummary] {
        (0..<count).map { i in
            let heavy = i.isMultiple(of: 3)
            return DaySummary(day: Date(), caffeineMg: heavy ? Double(300 + i) : Double(120 + i * 5),
                              bedtimeLevelMg: heavy ? 70 : 15, sleepQuality: heavy ? 2 : 4,
                              sleepMinutes: heavy ? 390 : 455)
        }
    }

    func testSleepDurationInsightAndAverage() {
        let days = history()
        XCTAssertTrue(InsightEngine.insights(days).contains {
            if case .lateCaffeineShortensSleep(_, let lost) = $0 { lost > 60 } else { false }
        })
        let summary = WeeklySummary.make(Array(days.prefix(3)), dailyLimitMg: 400)
        XCTAssertEqual(summary.averageSleepMinutes!, (390 + 455 + 455) / 3, accuracy: 0.01)
    }
}

final class CaffeineLimitTests: XCTestCase {
    func testGeneralReferenceWithoutProfile() {
        let r = CaffeineLimit.daily(for: nil)
        XCTAssertEqual(r.dailyMg, 400)
        XCTAssertEqual(r.basis, .generalReference)
    }

    func testAdultScalesWithWeightAndCapsAt400() {
        XCTAssertEqual(CaffeineLimit.daily(for: CaffeineProfile(age: 30, weightKg: 70)).dailyMg, 400)
        XCTAssertEqual(CaffeineLimit.daily(for: CaffeineProfile(age: 30, weightKg: 95)).basis, .adultCap)
        XCTAssertEqual(CaffeineLimit.daily(for: CaffeineProfile(age: 30, weightKg: 95)).dailyMg, 400)
        let light = CaffeineLimit.daily(for: CaffeineProfile(age: 30, weightKg: 52))
        XCTAssertEqual(light.basis, .adultWeight)
        XCTAssertEqual(light.dailyMg, 295) // 52 × 5.71 = 297 → rounded down to 5 mg
    }

    func testUnder18UsesThreeMgPerKg() {
        let r = CaffeineLimit.daily(for: CaffeineProfile(age: 16, weightKg: 60))
        XCTAssertEqual(r.dailyMg, 180)
        XCTAssertEqual(r.basis, .youthWeight)
    }

    func testPregnancyCapsAt200() {
        let r = CaffeineLimit.daily(for: CaffeineProfile(age: 32, weightKg: 70, pregnantOrBreastfeeding: true))
        XCTAssertEqual(r.dailyMg, 200)
        XCTAssertEqual(r.basis, .pregnancy)
        // A lower weight-based limit is kept.
        let teen = CaffeineLimit.daily(for: CaffeineProfile(age: 17, weightKg: 50, pregnantOrBreastfeeding: true))
        XCTAssertEqual(teen.dailyMg, 150)
    }

    func testStatus() {
        XCTAssertEqual(CaffeineLimit.status(todayMg: 100, nextDoseMg: 60, limitMg: 300), .below)
        XCTAssertEqual(CaffeineLimit.status(todayMg: 240, nextDoseMg: 30, limitMg: 300), .approaching)
        XCTAssertEqual(CaffeineLimit.status(todayMg: 220, nextDoseMg: 95, limitMg: 300), .approaching)
        XCTAssertEqual(CaffeineLimit.status(todayMg: 300, nextDoseMg: 0, limitMg: 300), .approaching)
        XCTAssertEqual(CaffeineLimit.status(todayMg: 305, nextDoseMg: 0, limitMg: 300), .over)
    }
}

final class WaterGuideTests: XCTestCase {
    func testBaseFromWeight() {
        let t = WaterGuide.target(weightKg: 62, caffeineTodayMg: 0)
        XCTAssertEqual(t.baseMl, 1900) // 62 × 30 = 1860 → nearest 100
        XCTAssertEqual(t.caffeineExtraMl, 0)
        XCTAssertEqual(t.glasses, 10)
    }

    func testDefaultWeightAndCaffeineExtra() {
        let t = WaterGuide.target(weightKg: nil, caffeineTodayMg: 285)
        XCTAssertEqual(t.baseMl, 2100)
        XCTAssertEqual(t.caffeineExtraMl, 300) // 285 ml → nearest 50
        XCTAssertEqual(t.totalMl, 2400)
        XCTAssertEqual(t.glasses, 12)
    }
}
