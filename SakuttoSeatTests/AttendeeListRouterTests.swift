//
//  AttendeeListRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 4 / Phase 5
//  refactor_favorite.md Phase 0（同一 Gateway インスタンスの受け渡しを断言）
//  refactor_favorite.md Phase 4（Router はキャッシュしない。シート identity は親 Presenter）
//  refactor_groupFavorite.md Phase 4（assembleModule は渡された Gateway を起動時点から使う）
//  refactor_groupFavorite.md Phase 5（結合 makeFavoriteGroupModule は削除。Presenter + Sheet）
//  子モジュール生成と Output 結線を固定する。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class AttendeeListRouterTests: XCTestCase {

    func test_お気に入りモジュールは渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingGroupFavoriteGateway()
        try gateway.insert(name: "共有", members: ["A"])
        XCTAssertEqual(gateway.fetchSummariesCallCount, 0)

        let presenter = AttendeeListRouter().makeFavoriteGroupPresenter(
            gatewayHolder: AttendeeListInteractor(favoriteGateway: gateway),
            output: FavoriteGroupOutputSpy()
        )
        _ = AttendeeListRouter().makeFavoriteGroupSheet(presenter: presenter)
        _ = FavoriteGroupRouter.assembleModule(
            favoriteGateway: gateway,
            output: FavoriteGroupOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchSummariesCallCount, 2)
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

    func test_presentRewardedAdは注入したGatewayを1回呼ぶ() async throws {
        let fake = RewardedAdGatewayFake(outcome: .success)
        let router = AttendeeListRouter(rewardedAd: fake)

        try await router.presentRewardedAd()

        XCTAssertEqual(fake.presentCallCount, 1)
    }

    func test_presentRewardedAdはFakeのnotReadyを再throwする() async {
        let fake = RewardedAdGatewayFake(outcome: .notReady)
        let router = AttendeeListRouter(rewardedAd: fake)

        do {
            try await router.presentRewardedAd()
            XCTFail("expected notReady")
        } catch RewardedAdError.notReady {
            XCTAssertEqual(fake.presentCallCount, 1)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
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
