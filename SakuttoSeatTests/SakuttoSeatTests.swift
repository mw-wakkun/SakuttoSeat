//
//  SakuttoSeatTests.swift
//  SakuttoSeatTests
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import XCTest
@testable import SakuttoSeat
import Foundation

// XCTest-based unit tests so they run in Xcode's default test runner.
@MainActor
final class SakuttoSeatTests: XCTestCase {

    func testAddAttendee() async throws {
        let interactor = AttendeeListInteractor()
        _ = interactor.addAttendee(name: "田中")

        let attendees = interactor.fetchAttendees()
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
        _ = interactor.addAttendee(name: "A")
        _ = interactor.addAttendee(name: "B")
        _ = interactor.addAttendee(name: "C")
        _ = interactor.addAttendee(name: "D")
        _ = interactor.addAttendee(name: "E")

        let original = interactor.fetchAttendees()
        _ = interactor.shuffleAttendees()
        let shuffled = interactor.fetchAttendees()

        XCTAssertEqual(original.count, shuffled.count)
        // It's possible (rare) that shuffle returns same order; allow retry to reduce flakiness
        if original == shuffled {
            // retry once more
            _ = interactor.shuffleAttendees()
            let shuffled2 = interactor.fetchAttendees()
            XCTAssertNotEqual(original, shuffled2, "Shuffle produced same order after retry — this is unlikely but possible due to randomness.")
        } else {
            XCTAssertNotEqual(original, shuffled)
        }
    }
}
