//
//  SakuttoSeatTests.swift
//  SakuttoSeatTests
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import XCTest
@testable import SakuttoSeat
import Foundation

// Xcode のデフォルトテストランナーで実行できるXCTestベースのユニットテスト
@MainActor
final class SakuttoSeatTests: XCTestCase {

    func testAddAttendee() async throws {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(name: "田中")

        let attendees = interactor.allAttendees()
        XCTAssertEqual(attendees.count, 1)
        XCTAssertEqual(attendees.first?.name, "田中")
    }

    func testTrimsWhitespaceInName() async throws {
        let presenter = AttendeeListPresenter(
            interactor: AttendeeListInteractor(),
            router: AttendeeListRouter()
        )

        presenter.didTapAddButton(name: "  佐藤  ")
        XCTAssertEqual(presenter.attendees.first?.name, "佐藤")
    }

    func testShuffleChangesOrder() async throws {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(name: "A")
        _ = interactor.add(name: "B")
        _ = interactor.add(name: "C")
        _ = interactor.add(name: "D")
        _ = interactor.add(name: "E")

        let original = interactor.allAttendees()
        _ = interactor.shuffle()
        let shuffled = interactor.allAttendees()

        XCTAssertEqual(original.count, shuffled.count)
        // シャッフルが同じ順序を返す可能性は低いが存在するため、リトライで安定性を確保
        if original == shuffled {
            // もう一度リトライ
            _ = interactor.shuffle()
            let shuffled2 = interactor.allAttendees()
            XCTAssertNotEqual(original, shuffled2, "シャッフルがリトライ後も同じ順序を返した — ランダム性により稀だが可能")
        } else {
            XCTAssertNotEqual(original, shuffled)
        }
    }
}
