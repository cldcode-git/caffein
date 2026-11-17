import XCTest
@testable import CaffeineKit

final class RestingPulseTests: XCTestCase {
    func testWithoutProfileUsesGeneralAdultReference() {
        let r = RestingPulse.reference(for: nil)
        XCTAssertEqual(r.typicalBPM, 72)
        XCTAssertEqual(r.elevatedFromBPM, 87)
        XCTAssertEqual(r.highFromBPM, 97)
        XCTAssertFalse(r.isPersonal)
    }

    func testWomenRunAFewBeatsHigherThanMen() {
        let woman = RestingPulse.reference(for: CaffeineProfile(age: 30, weightKg: 62, sex: .female))
        let man = RestingPulse.reference(for: CaffeineProfile(age: 30, weightKg: 78, sex: .male))
        XCTAssertEqual(woman.typicalBPM, 74)
        XCTAssertEqual(woman.elevatedFromBPM, 89)
        XCTAssertEqual(woman.highFromBPM, 99)
        XCTAssertEqual(man.typicalBPM, 70)
        XCTAssertEqual(man.elevatedFromBPM, 85)
        XCTAssertEqual(man.highFromBPM, 95)
        XCTAssertTrue(woman.isPersonal)
    }

    func testTeenagersHigherOlderAdultsLower() {
        let teen = RestingPulse.reference(for: CaffeineProfile(age: 16, weightKg: 55, sex: .female))
        XCTAssertEqual(teen.typicalBPM, 79)
        XCTAssertEqual(teen.highFromBPM, 100, "never later than the clinical upper limit")
        let older = RestingPulse.reference(for: CaffeineProfile(age: 70, weightKg: 75, sex: .male))
        XCTAssertEqual(older.typicalBPM, 68)
    }

    func testWeightAddsAtMostFiveBeats() {
        let heavier = RestingPulse.reference(for: CaffeineProfile(age: 40, weightKg: 105, sex: .male))
        XCTAssertEqual(heavier.typicalBPM, 72) // 25 kg over → +2
        let veryHeavy = RestingPulse.reference(for: CaffeineProfile(age: 40, weightKg: 200, sex: .male))
        XCTAssertEqual(veryHeavy.typicalBPM, 75)
        let light = RestingPulse.reference(for: CaffeineProfile(age: 40, weightKg: 50, sex: .male))
        XCTAssertEqual(light.typicalBPM, 70, "lower weight doesn't lower the reference")
    }

    func testHighThresholdStaysAboveElevated() {
        let r = RestingPulse.reference(for: CaffeineProfile(age: 15, weightKg: 120, sex: .female))
        XCTAssertEqual(r.elevatedFromBPM, 99)
        XCTAssertEqual(r.highFromBPM, 100)
    }

    func testLevels() {
        let woman = RestingPulse.reference(for: CaffeineProfile(age: 30, weightKg: 62, sex: .female))
        XCTAssertEqual(RestingPulse.level(bpm: 72, reference: woman), .normal)
        XCTAssertEqual(RestingPulse.level(bpm: 88, reference: woman), .normal)
        XCTAssertEqual(RestingPulse.level(bpm: 89, reference: woman), .elevated)
        XCTAssertEqual(RestingPulse.level(bpm: 99, reference: woman), .high)
        let man = RestingPulse.reference(for: CaffeineProfile(age: 30, weightKg: 78, sex: .male))
        XCTAssertEqual(RestingPulse.level(bpm: 88, reference: man), .elevated, "same pulse, different person")
    }
}
