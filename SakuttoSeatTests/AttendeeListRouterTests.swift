//
//  AttendeeListRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 4
//  子モジュール生成と Output 結線を固定する。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class AttendeeListRouterTests: XCTestCase {

    func test_assembleModuleがエントリ画面を返す() {
        _ = AttendeeListRouter.assembleModule()
    }

    func test_座席表モジュールを組み立てる() {
        let router = AttendeeListRouter()
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]

        _ = router.makeSeatingChartModule(attendees: attendees)
    }

    func test_番号札モジュールはSimpleShuffleRouterへ委譲する() {
        let attendees = [Attendee(name: "太郎"), Attendee(name: "花子")]

        _ = SimpleShuffleRouter.assembleModule(attendees: attendees)
        _ = AttendeeListRouter().makeSimpleShuffleModule(attendees: attendees)
    }

    func test_お気に入りシートはOutputを結線する() {
        let router = AttendeeListRouter()
        let output = FavoriteGroupOutputSpy()
        let groups = [
            FavoriteGroupSnapshot(
                id: UUID(),
                name: "同期",
                memberNames: ["太郎"],
                memberSummary: "太郎"
            )
        ]

        _ = router.makeFavoriteGroupModule(groups: groups, output: output)
    }

    func test_一括追加シートはOutputを結線する() {
        let router = AttendeeListRouter()
        let output = BulkAddOutputSpy()

        _ = router.makeBulkAddModule(output: output)
    }

    func test_RouterはProtocolに準拠する() {
        let router: any AttendeeListRouterProtocol = AttendeeListRouter()
        let attendees = [Attendee(name: "A")]

        _ = router.makeSeatingChartModule(attendees: attendees)
        _ = router.makeSimpleShuffleModule(attendees: attendees)
        _ = router.makeFavoriteGroupModule(groups: [], output: nil)
        _ = router.makeBulkAddModule(output: nil)
    }
}

@MainActor
private final class FavoriteGroupOutputSpy: FavoriteGroupModuleOutput {
    var selectedID: FavoriteGroupID?
    var deletedOffsets: IndexSet?
    var didCancel = false

    func favoriteGroupDidSelect(id: FavoriteGroupID) {
        selectedID = id
    }

    func favoriteGroupDidDelete(at offsets: IndexSet) {
        deletedOffsets = offsets
    }

    func favoriteGroupDidCancel() {
        didCancel = true
    }
}

@MainActor
private final class BulkAddOutputSpy: BulkAddModuleOutput {
    var confirmedText: String?
    var didCancel = false

    func bulkAddDidConfirm(text: String) {
        confirmedText = text
    }

    func bulkAddDidCancel() {
        didCancel = true
    }
}
