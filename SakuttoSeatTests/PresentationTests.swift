//
//  PresentationTests.swift
//  SakuttoSeatTests
//
//  v2.1 UI/UX（発表キャンバスの番号札列数。Snapshot の列数とは独立）
//

import CoreGraphics
import XCTest
@testable import SakuttoSeat

final class PresentationNumberedLayoutTests: XCTestCase {

    func test_1人は幅に依らず1列() {
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 1, containerWidth: 390), 1)
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 1, containerWidth: 800), 1)
    }

    func test_縦iPhone相当は2列() {
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 40, containerWidth: 390), 2)
    }

    func test_中幅は3列() {
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 40, containerWidth: 600), 3)
    }

    func test_広い幅は4列() {
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 40, containerWidth: 800), 4)
    }

    func test_列数は人数を超えない() {
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 2, containerWidth: 800), 2)
        XCTAssertEqual(PresentationNumberedLayout.columnCount(rowCount: 3, containerWidth: 600), 3)
    }
}

final class PresentationDismissGestureTests: XCTestCase {

    func test_先頭かつ上端からなら下方向の十分なスワイプで閉じる() {
        XCTAssertTrue(
            PresentationDismissGesture.shouldDismiss(
                translation: CGSize(width: 0, height: 81),
                startLocation: CGPoint(x: 200, y: 40),
                isScrollAtTop: true
            )
        )
    }

    func test_キャンバス中央の下スワイプでは閉じない() {
        XCTAssertFalse(
            PresentationDismissGesture.shouldDismiss(
                translation: CGSize(width: 0, height: 200),
                startLocation: CGPoint(x: 200, y: 240),
                isScrollAtTop: true
            )
        )
    }

    func test_内容が動いている下スワイプでは閉じない() {
        XCTAssertFalse(
            PresentationDismissGesture.shouldDismiss(
                translation: CGSize(width: 0, height: 200),
                startLocation: CGPoint(x: 200, y: 40),
                isScrollAtTop: false
            )
        )
    }

    func test_横移動が主なら先頭でも閉じない() {
        XCTAssertFalse(
            PresentationDismissGesture.shouldDismiss(
                translation: CGSize(width: 80, height: 81),
                startLocation: CGPoint(x: 200, y: 40),
                isScrollAtTop: true
            )
        )
    }

    func test_閾値未満では閉じない() {
        XCTAssertFalse(
            PresentationDismissGesture.shouldDismiss(
                translation: CGSize(width: 0, height: 80),
                startLocation: CGPoint(x: 200, y: 40),
                isScrollAtTop: true
            )
        )
    }

    func test_オフセットがinset以下なら先頭() {
        XCTAssertTrue(PresentationDismissGesture.isScrollAtTop(offsetY: 0, insetTop: 0))
        XCTAssertTrue(PresentationDismissGesture.isScrollAtTop(offsetY: -8, insetTop: 0))
        XCTAssertFalse(PresentationDismissGesture.isScrollAtTop(offsetY: 20, insetTop: 0))
    }
}
