//
//  AttendeeListPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0 / Phase 1 / Phase 2 / Phase 3 / Phase 4 / Phase 5
//  refactor_favorite.md Phase 0（お気に入りシートの Gateway 共有を断言）
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
        XCTAssertEqual(saved.first?.memberNames, ["太郎", "花子"])
        XCTAssertNil(presenter.route)
    }

    func test_お気に入り選択で参加者リストを置換する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "新メンバ", members: ["新1", "新2", "新3"])
        let presenter = makePresenter(names: ["旧1", "旧2"], gateway: gateway)

        presenter.didSelectFavoriteGroup(id: try XCTUnwrap(gateway.fetchAll().first?.id))

        XCTAssertEqual(names(of: presenter), ["新1", "新2", "新3"])
        XCTAssertNil(presenter.route)
    }

    func test_メンバーが空のお気に入りを選ぶとリストが空になる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "空", members: [])
        let presenter = makePresenter(names: ["残したくない"], gateway: gateway)

        presenter.didSelectFavoriteGroup(id: try XCTUnwrap(gateway.fetchAll().first?.id))

        XCTAssertTrue(presenter.viewData.isEmpty)
    }

    func test_空白のみのグループ名では保存しない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let presenter = makePresenter(names: ["A"], gateway: gateway)
        presenter.didTapSaveFavorite()

        presenter.didConfirmSaveFavorite(name: "   ")

        XCTAssertTrue(try gateway.fetchAll().isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_お気に入り保存失敗はアラートになる() {
        let presenter = makePresenter(names: ["A"], gateway: FailingInsertGroupFavoriteGateway())

        presenter.didConfirmSaveFavorite(name: "同期")

        XCTAssertEqual(
            presenter.route,
            .alert(.saveFailed(message: "書き込みに失敗しました"))
        )
        XCTAssertEqual(names(of: presenter), ["A"])
    }

    func test_存在しないお気に入りを選んでもリストとRouteは変わらない() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapShowFavorites()

        presenter.didSelectFavoriteGroup(id: UUID())

        XCTAssertEqual(names(of: presenter), ["A"])
        XCTAssertEqual(presenter.route, .favoriteList)
    }

    // MARK: - 子モジュール Output（Phase 5）

    func test_FavoriteGroupOutputの選択はリストを置換してシートを閉じる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "新メンバ", members: ["新1", "新2"])
        let presenter = makePresenter(names: ["旧"], gateway: gateway)
        presenter.didTapShowFavorites()

        presenter.favoriteGroupDidSelect(id: try XCTUnwrap(gateway.fetchAll().first?.id))

        XCTAssertEqual(names(of: presenter), ["新1", "新2"])
        XCTAssertNil(presenter.route)
    }

    func test_FavoriteGroupOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter()
        presenter.didTapShowFavorites()

        presenter.favoriteGroupDidCancel()

        XCTAssertNil(presenter.route)
    }

    func test_お気に入りシートは親と同じGatewayインスタンスで組み立てる() throws {
        let gateway = FetchCountingGroupFavoriteGateway()
        try gateway.insert(name: "共有", members: ["A"])
        let presenter = makePresenter(gateway: gateway)
        let fetchCountBeforeSheet = gateway.fetchAllCallCount

        presenter.didTapShowFavorites()
        _ = presenter.makeRouteSheet(.favoriteList)

        XCTAssertEqual(presenter.route, .favoriteList)
        XCTAssertGreaterThan(gateway.fetchAllCallCount, fetchCountBeforeSheet)
    }

    func test_BulkAddOutputの確定は一括追加してシートを閉じる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapBulkAddEntry()

        presenter.bulkAddDidConfirm(text: "B,C")

        XCTAssertEqual(names(of: presenter), ["A", "B", "C"])
        XCTAssertNil(presenter.route)
    }

    func test_BulkAddOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter()
        presenter.didTapBulkAddEntry()

        presenter.bulkAddDidCancel()

        XCTAssertNil(presenter.route)
    }

    func test_makeRouteViewは座席表と番号札を組み立てる() {
        let presenter = makePresenter(names: ["A"])

        _ = presenter.makeRouteView(.seatingChart)
        _ = presenter.makeRouteView(.simpleShuffle)
    }

    func test_makeRouteSheetはお気に入りと一括追加を組み立てる() {
        let presenter = makePresenter(names: ["A"])

        _ = presenter.makeRouteSheet(.favoriteList)
        _ = presenter.makeRouteSheet(.bulkAdd)
    }
}

/// insert だけ失敗させるテスト用 Gateway
private final class FailingInsertGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func insert(name: String, members: [String]) throws {
        throw NSError(
            domain: "AttendeeListTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "書き込みに失敗しました"]
        )
    }
}

/// 親シート組み立てが同じ Gateway インスタンスを子へ渡すことを数える
private final class FetchCountingGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private var snapshots: [FavoriteGroupSnapshot] = []
    private(set) var fetchAllCallCount = 0

    override func fetchCount() throws -> Int { snapshots.count }

    override func fetchAll() throws -> [FavoriteGroupSnapshot] {
        fetchAllCallCount += 1
        return snapshots
    }

    override func insert(name: String, members: [String]) throws {
        snapshots.append(FavoriteGroupSnapshot.persisted(name: name, memberNames: members))
    }
}
