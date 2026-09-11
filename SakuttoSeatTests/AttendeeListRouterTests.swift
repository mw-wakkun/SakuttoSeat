//
//  AttendeeListRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 4 / Phase 5
//  refactor_favorite.md Phase 0（同一 Gateway インスタンスの受け渡しを断言）
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

    func test_番号札モジュールは空配列でも組み立てられる() {
        _ = AttendeeListRouter().makeSimpleShuffleModule(attendees: [])
    }

    func test_お気に入りモジュールはFavoriteGroupRouterへ委譲する() {
        let router = AttendeeListRouter()
        let output = FavoriteGroupOutputSpy()

        _ = router.makeFavoriteGroupModule(
            favoriteGateway: InMemoryGroupFavoriteGateway(),
            output: output
        )
        _ = FavoriteGroupRouter.assembleModule(output: output)
    }

    func test_お気に入りモジュールは渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "共有", members: ["A"]))
        XCTAssertEqual(gateway.fetchAllCallCount, 0)

        _ = AttendeeListRouter().makeFavoriteGroupModule(
            favoriteGateway: gateway,
            output: FavoriteGroupOutputSpy()
        )
        _ = FavoriteGroupRouter.assembleModule(
            favoriteGateway: gateway,
            output: FavoriteGroupOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchAllCallCount, 2)
    }

    func test_一括追加モジュールはBulkAddRouterへ委譲する() {
        let router = AttendeeListRouter()
        let output = BulkAddOutputSpy()

        _ = router.makeBulkAddModule(output: output)
        _ = BulkAddRouter.assembleModule(output: output)
    }

    func test_RouterはProtocolに準拠する() {
        let router: any AttendeeListRouterProtocol = AttendeeListRouter()
        let attendees = [Attendee(name: "A")]

        _ = router.makeSeatingChartModule(attendees: attendees)
        _ = router.makeSimpleShuffleModule(attendees: attendees)
        _ = router.makeFavoriteGroupModule(favoriteGateway: InMemoryGroupFavoriteGateway(), output: nil)
        _ = router.makeBulkAddModule(output: nil)
    }
}

private final class FetchCountingGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private var favorites: [GroupFavorite] = []
    private(set) var fetchAllCallCount = 0

    override func fetchCount() throws -> Int { favorites.count }

    override func fetchAll() throws -> [GroupFavorite] {
        fetchAllCallCount += 1
        return favorites.sorted { $0.createdAt > $1.createdAt }
    }

    override func insert(_ favorite: GroupFavorite) throws {
        favorites.append(favorite)
    }
}

@MainActor
private final class FavoriteGroupOutputSpy: FavoriteGroupModuleOutput {
    var selectedID: FavoriteGroupID?
    var didCancel = false

    func favoriteGroupDidSelect(id: FavoriteGroupID) {
        selectedID = id
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
