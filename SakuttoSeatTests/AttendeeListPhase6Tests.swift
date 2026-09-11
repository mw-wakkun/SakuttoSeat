//
//  AttendeeListPhase6Tests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 6（番号行 A11y・アダプティブバナー寸法）
//

import XCTest
@testable import SakuttoSeat

final class NumberedPersonCopyTests: XCTestCase {

    func test_参加者行は番号と名前を読み上げる() {
        XCTAssertEqual(
            NumberedPersonCopy.accessibilityLabel(number: 1, name: "太郎", accessory: nil),
            "1番、太郎"
        )
    }

    func test_番号札行は番席を含めて読み上げる() {
        XCTAssertEqual(
            NumberedPersonCopy.accessibilityLabel(number: 3, name: "花子", accessory: "番席"),
            "3番席、花子"
        )
    }
}

final class AdBannerMetricsTests: XCTestCase {

    func test_アダプティブバナーは幅に応じたサイズを返す() {
        let compact = AdBannerMetrics.size(forWidth: 320)
        let regular = AdBannerMetrics.size(forWidth: 390)

        XCTAssertGreaterThan(compact.width, 0)
        XCTAssertGreaterThanOrEqual(compact.height, 50)
        XCTAssertGreaterThan(regular.width, 0)
        XCTAssertGreaterThanOrEqual(regular.height, 50)
    }
}
