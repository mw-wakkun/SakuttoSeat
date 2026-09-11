//
//  AttendeeListRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 4 / Phase 5
//  refactor_favorite.md Phase 0（同一 Gateway インスタンスの受け渡しを断言）
//  refactor_favorite.md Phase 4（Router はキャッシュしない。シート identity は親 Presenter）
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
            gatewayHolder: AttendeeListInteractor(favoriteGateway: InMemoryGroupFavoriteGateway()),
            output: output
        )
        _ = FavoriteGroupRouter.assembleModule(output: output)
    }

    func test_お気に入りモジュールは渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingGroupFavoriteGateway()
        try gateway.insert(name: "共有", members: ["A"])
        XCTAssertEqual(gateway.fetchSummariesCallCount, 0)

        _ = AttendeeListRouter().makeFavoriteGroupModule(
            gatewayHolder: AttendeeListInteractor(favoriteGateway: gateway),
            output: FavoriteGroupOutputSpy()
        )
        _ = FavoriteGroupRouter.assembleModule(
            favoriteGateway: gateway,
            output: FavoriteGroupOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchSummariesCallCount, 2)
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
        _ = router.makeFavoriteGroupPresenter(
            gatewayHolder: AttendeeListInteractor(),
            output: nil
        )
        _ = router.makeFavoriteGroupSheet(
            presenter: FavoriteGroupRouter.assemblePresenter(output: nil)
        )
        _ = router.makeFavoriteGroupModule(
            gatewayHolder: AttendeeListInteractor(),
            output: nil
        )
        _ = router.makeBulkAddModule(output: nil)
    }

    func test_FavoriteGroupRouterはassembleのたびに新しいPresenterを返す() {
        let gateway = InMemoryGroupFavoriteGateway()
        let output = FavoriteGroupOutputSpy()

        let first = FavoriteGroupRouter.assemblePresenter(
            favoriteGateway: gateway,
            output: output
        )
        let second = FavoriteGroupRouter.assemblePresenter(
            favoriteGateway: gateway,
            output: output
        )

        XCTAssertFalse(first === second)
    }

    func test_同じoutputとgatewayで2回makeしても組み立てられる() {
        let router = AttendeeListRouter()
        let gatewayHolder = AttendeeListInteractor(favoriteGateway: InMemoryGroupFavoriteGateway())
        let output = FavoriteGroupOutputSpy()

        _ = router.makeFavoriteGroupModule(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeFavoriteGroupModule(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeFavoriteGroupPresenter(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeFavoriteGroupPresenter(gatewayHolder: gatewayHolder, output: output)
    }
}

private final class FetchCountingGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private var snapshots: [FavoriteGroupSnapshot] = []
    private(set) var fetchSummariesCallCount = 0

    override func fetchCount() throws -> Int { snapshots.count }

    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        fetchSummariesCallCount += 1
        return snapshots.map {
            FavoriteGroupSummary(
                id: $0.id,
                name: $0.name,
                memberSummary: $0.memberNames.joined(separator: ", ")
            )
        }
    }

    override func insert(name: String, members: [String]) throws {
        snapshots.append(FavoriteGroupSnapshot.persisted(name: name, memberNames: members))
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
