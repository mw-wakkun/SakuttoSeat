//
//  BulkAddTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 5（一括追加子モジュールの回帰）
//

import Combine
import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class BulkAddInteractorTests: XCTestCase {

    func test_空文字では確定できない() {
        let interactor = BulkAddInteractor()

        XCTAssertFalse(interactor.canConfirm)
        XCTAssertEqual(interactor.text, "")
    }

    func test_空白のみでは確定できない() {
        let interactor = BulkAddInteractor()

        interactor.updateText("   \n")

        XCTAssertFalse(interactor.canConfirm)
        XCTAssertEqual(interactor.text, "   \n")
    }

    func test_名前が入ると確定できる() {
        let interactor = BulkAddInteractor()

        interactor.updateText("太郎,花子")

        XCTAssertTrue(interactor.canConfirm)
        XCTAssertEqual(interactor.text, "太郎,花子")
    }

    func test_区切り説明は実装の分割文字と一致する文言を返す() {
        let interactor = BulkAddInteractor()

        XCTAssertTrue(interactor.delimiterHint.contains(","))
        XCTAssertTrue(interactor.delimiterHint.contains("、"))
        XCTAssertTrue(interactor.delimiterHint.contains("改行"))
    }
}

// MARK: - Presenter

@MainActor
final class BulkAddPresenterTests: XCTestCase {

    private final class OutputSpy: BulkAddModuleOutput {
        var confirmedText: String?
        var cancelCount = 0

        func bulkAddDidConfirm(text: String) { confirmedText = text }
        func bulkAddDidCancel() { cancelCount += 1 }
    }

    func test_入力はViewDataへ反映される() {
        let presenter = BulkAddPresenter(output: OutputSpy())

        presenter.didChangeText("太郎\n花子")

        XCTAssertEqual(presenter.viewData.text, "太郎\n花子")
        XCTAssertTrue(presenter.viewData.canConfirm)
        XCTAssertEqual(presenter.viewData.delimiterHint, BulkAddCopy.delimiterHint)
    }

    func test_同一テキストではobjectWillChangeを発火しない() {
        let presenter = BulkAddPresenter(output: OutputSpy())
        presenter.didChangeText("太郎")

        var changeCount = 0
        let cancellable = presenter.objectWillChange.sink { changeCount += 1 }
        presenter.didChangeText("太郎")

        XCTAssertEqual(changeCount, 0)
        _ = cancellable
    }

    func test_空の確定はOutputへ送らない() {
        let output = OutputSpy()
        let presenter = BulkAddPresenter(output: output)

        presenter.didTapConfirm()

        XCTAssertNil(output.confirmedText)
    }

    func test_確定は生テキストをOutputへ渡す() {
        let output = OutputSpy()
        let presenter = BulkAddPresenter(output: output)
        presenter.didChangeText("太郎, 花子")

        presenter.didTapConfirm()

        XCTAssertEqual(output.confirmedText, "太郎, 花子")
    }

    func test_キャンセルはOutputへ通知する() {
        let output = OutputSpy()
        let presenter = BulkAddPresenter(output: output)

        presenter.didTapCancel()

        XCTAssertEqual(output.cancelCount, 1)
    }
}
