//
//  AttendeeListPhase6Tests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 6（番号行 A11y・アダプティブバナー寸法）
//  refactor_Ad.md Phase 0（寸法テストは維持。再 load 判断は AdsPhase0Tests）
//  refactor_Ad.md Phase 5（Metrics は @testable。Representable は fileprivate）
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

    func test_アダプティブバナーは指定幅を超えて親を押し広げない() {
        let width: CGFloat = 390
        let size = AdBannerMetrics.size(forWidth: width)

        XCTAssertEqual(size.width, width, accuracy: 0.5)
        // 標準アンカーは 50〜90pt（large は最大 150pt）。ボトムクロムはこちらを使う。
        XCTAssertGreaterThanOrEqual(size.height, 50)
        XCTAssertLessThanOrEqual(size.height, 90)
    }
}
