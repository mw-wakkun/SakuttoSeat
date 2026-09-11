//
//  AttendeeListPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0 / Phase 1 / Phase 2
//  意図メソッド → ViewData / Route の契約を固定する。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class AttendeeListPresenterTests: XCTestCase {

    private func makePresenter(
        names: [String] = [],
        gateway: GroupFavoriteGatewayBase = InMemoryGroupFavoriteGateway()
    ) -> AttendeeListPresenter {
        let interactor = AttendeeListInteractor()
        if !names.isEmpty {
            _ = interactor.add(fromText: names.joined(separator: ","))
        }
        let presenter = AttendeeListPresenter(interactor: interactor, router: AttendeeListRouter())
        presenter.attachFavoriteGateway(gateway)
        presenter.onAppear()
        return presenter
    }

    private func names(of presenter: AttendeeListPresenter) -> [String] {
        presenter.viewData.rows.map(\.name)
    }

    // MARK: - 参加者 / ViewData

    func test_追加時に前後空白を除去する() {
        let presenter = makePresenter()

        presenter.didTapAdd(name: "  佐藤  ")

        XCTAssertEqual(names(of: presenter), ["佐藤"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1])
        XCTAssertTrue(presenter.viewData.canStartSeating)
        XCTAssertFalse(presenter.viewData.isEmpty)
    }

    func test_onAppearでInteractorの一覧をViewDataに公開する() {
        let presenter = makePresenter(names: ["A", "B"])

        XCTAssertEqual(names(of: presenter), ["A", "B"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2])
    }

    func test_単一削除で指定行だけ消える() {
        let presenter = makePresenter(names: ["A", "B", "C"])

        presenter.didDeleteAttendees(at: IndexSet(integer: 1))

        XCTAssertEqual(names(of: presenter), ["A", "C"])
        XCTAssertEqual(presenter.viewData.rows.map(\.number), [1, 2])
    }

    func test_複数削除はIndexSetを一度だけ適用する() {
        let presenter = makePresenter(names: ["A", "B", "C", "D"])

        presenter.didDeleteAttendees(at: IndexSet([0, 2]))

        XCTAssertEqual(names(of: presenter), ["B", "D"])
    }

    func test_リセットは確認Routeのあと全員削除する() {
        let presenter = makePresenter(names: ["A", "B"])

        presenter.didTapReset()
        XCTAssertEqual(presenter.route, .alert(.confirmReset))
        XCTAssertEqual(names(of: presenter), ["A", "B"])

        presenter.didConfirmReset()

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertFalse(presenter.viewData.canReset)
        XCTAssertNil(presenter.route)
    }

    func test_一括追加の結果をそのまま公開する() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapBulkAdd(text: "A,B")

        XCTAssertEqual(names(of: presenter), ["A", "A(2)", "B"])
        XCTAssertNil(presenter.route)
    }

    // MARK: - Route

    func test_座席表タップでrouteがseatingChartになる() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSeatingChart()

        XCTAssertEqual(presenter.route, .seatingChart)
        XCTAssertTrue(presenter.route?.presentsAsNavigation == true)
    }

    func test_番号札タップでrouteがsimpleShuffleになる() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSimpleShuffle()

        XCTAssertEqual(presenter.route, .simpleShuffle)
        XCTAssertTrue(presenter.route?.presentsAsNavigation == true)
    }

    func test_お気に入り一覧タップでrouteがfavoriteListになる() {
        let presenter = makePresenter()

        presenter.didTapShowFavorites()

        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertTrue(presenter.route?.presentsAsSheet == true)
    }

    func test_一括追加タップでrouteがbulkAddになる() {
        let presenter = makePresenter()

        presenter.didTapBulkAddEntry()

        XCTAssertEqual(presenter.route, .bulkAdd)
        XCTAssertTrue(presenter.route?.presentsAsSheet == true)
    }

    func test_dismissRouteで提示を閉じる() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
    }

    // MARK: - お気に入り

    func test_お気に入り保存が可能ならプロンプトを出す() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapSaveFavorite()

        XCTAssertEqual(presenter.route, .saveFavoritePrompt)
        XCTAssertTrue(presenter.route?.presentsAsAlert == true)
    }

    func test_お気に入りが上限に達するとアラートになる() {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        for index in 1...FeatureLimit.freeFavoriteGroupCount {
            presenter.didConfirmSaveFavorite(name: "グループ\(index)")
        }

        presenter.didTapSaveFavorite()

        XCTAssertEqual(
            presenter.route,
            .alert(.favoriteLimitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            ))
        )
    }

    func test_現在の参加者をお気に入りに保存する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["太郎", "花子"], gateway: gateway)

        presenter.didConfirmSaveFavorite(name: "同期")

        let saved = try gateway.fetchAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.name, "同期")
        XCTAssertEqual(saved.first?.members, ["太郎", "花子"])
        XCTAssertEqual(presenter.viewData.favoriteGroups.map(\.name), ["同期"])
        XCTAssertEqual(presenter.viewData.favoriteGroups.first?.memberSummary, "太郎, 花子")
        XCTAssertNil(presenter.route)
    }

    func test_お気に入り選択で参加者リストを置換する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "新メンバ", members: ["新1", "新2", "新3"]))
        let presenter = makePresenter(names: ["旧1", "旧2"], gateway: gateway)

        presenter.didSelectFavoriteGroup(id: presenter.viewData.favoriteGroups[0].id)

        XCTAssertEqual(names(of: presenter), ["新1", "新2", "新3"])
        XCTAssertNil(presenter.route)
    }

    func test_メンバーが空のお気に入りを選ぶとリストが空になる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "空", members: []))
        let presenter = makePresenter(names: ["残したくない"], gateway: gateway)

        presenter.didSelectFavoriteGroup(id: presenter.viewData.favoriteGroups[0].id)

        XCTAssertTrue(presenter.viewData.isEmpty)
    }

    func test_お気に入りをoffset指定で削除する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(gateway: gateway)
        presenter.didConfirmSaveFavorite(name: "古い")
        presenter.didConfirmSaveFavorite(name: "新しい")

        let before = presenter.viewData.favoriteGroups
        XCTAssertEqual(before.count, 2)
        let removedName = before[0].name

        presenter.didDeleteFavoriteGroups(at: IndexSet(integer: 0))

        let after = presenter.viewData.favoriteGroups
        XCTAssertEqual(after.count, 1)
        XCTAssertNotEqual(after.first?.name, removedName)
    }

    func test_空白のみのグループ名では保存しない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        presenter.didTapSaveFavorite()

        presenter.didConfirmSaveFavorite(name: "   ")

        XCTAssertTrue(try gateway.fetchAll().isEmpty)
        XCTAssertTrue(presenter.viewData.favoriteGroups.isEmpty)
        XCTAssertNil(presenter.route)
    }
}
