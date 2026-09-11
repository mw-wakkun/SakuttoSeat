//
//  AttendeeListViewDataTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 2（ViewData / Route の回帰）
//

import XCTest
@testable import SakuttoSeat

final class AttendeeListViewDataTests: XCTestCase {

    func test_空のときは席決めも保存もリセットもできない() {
        let viewData = AttendeeListViewDataBuilder.build(attendees: [])

        XCTAssertTrue(viewData.isEmpty)
        XCTAssertTrue(viewData.rows.isEmpty)
        XCTAssertFalse(viewData.canStartSeating)
        XCTAssertFalse(viewData.canSaveFavorite)
        XCTAssertFalse(viewData.canReset)
        XCTAssertTrue(viewData.favoriteGroups.isEmpty)
    }

    func test_行番号は1始まりでAttendeeのidを引き継ぐ() {
        let attendees = [Attendee(name: "A"), Attendee(name: "B"), Attendee(name: "C")]

        let viewData = AttendeeListViewDataBuilder.build(attendees: attendees)

        XCTAssertEqual(viewData.rows.map(\.number), [1, 2, 3])
        XCTAssertEqual(viewData.rows.map(\.name), ["A", "B", "C"])
        XCTAssertEqual(viewData.rows.map(\.id), attendees.map(\.id))
        XCTAssertTrue(viewData.canStartSeating)
        XCTAssertTrue(viewData.canSaveFavorite)
        XCTAssertTrue(viewData.canReset)
        XCTAssertFalse(viewData.isEmpty)
    }

    func test_お気に入りスナップショットをViewDataに載せられる() {
        let snapshot = FavoriteGroupSnapshot(
            id: UUID(),
            name: "同期",
            memberNames: ["太郎", "花子"],
            memberSummary: "太郎, 花子"
        )

        let viewData = AttendeeListViewDataBuilder.build(
            attendees: [Attendee(name: "太郎")],
            favoriteGroups: [snapshot]
        )

        XCTAssertEqual(viewData.favoriteGroups, [snapshot])
    }

    func test_Routeの提示区分() {
        XCTAssertTrue(AttendeeListRoute.favoriteList.presentsAsSheet)
        XCTAssertTrue(AttendeeListRoute.bulkAdd.presentsAsSheet)
        XCTAssertFalse(AttendeeListRoute.seatingChart.presentsAsSheet)

        XCTAssertTrue(AttendeeListRoute.seatingChart.presentsAsNavigation)
        XCTAssertTrue(AttendeeListRoute.simpleShuffle.presentsAsNavigation)
        XCTAssertFalse(AttendeeListRoute.favoriteList.presentsAsNavigation)

        XCTAssertTrue(AttendeeListRoute.saveFavoritePrompt.presentsAsAlert)
        XCTAssertTrue(AttendeeListRoute.alert(.confirmReset).presentsAsAlert)
        XCTAssertFalse(AttendeeListRoute.bulkAdd.presentsAsAlert)
    }
}
