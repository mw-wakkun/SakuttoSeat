//
//  FavoriteGroupTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧子モジュールの回帰）
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class FavoriteGroupInteractorTests: XCTestCase {

    func test_一覧は新しい順のスナップショットを返す() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let older = GroupFavorite(name: "古い", members: ["A"])
        older.createdAt = Date(timeIntervalSince1970: 1)
        let newer = GroupFavorite(name: "新しい", members: ["B", "C"])
        newer.createdAt = Date(timeIntervalSince1970: 2)
        try gateway.insert(older)
        try gateway.insert(newer)
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)

        let groups = interactor.allFavorites()

        XCTAssertEqual(groups.map(\.name), ["新しい", "古い"])
        XCTAssertEqual(groups.first?.memberNames, ["B", "C"])
        XCTAssertEqual(groups.first?.memberSummary, "B, C")
    }

    func test_offset指定で削除する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "古い", members: ["A"]))
        try gateway.insert(GroupFavorite(name: "新しい", members: ["B"]))
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)

        try interactor.deleteFavorites(at: IndexSet(integer: 0))

        XCTAssertEqual(interactor.allFavorites().map(\.name), ["古い"])
    }

    func test_削除失敗はpersistenceFailedになる() {
        let interactor = FavoriteGroupInteractor(favoriteGateway: FailingDeleteGroupFavoriteGateway())

        XCTAssertThrowsError(try interactor.deleteFavorites(at: IndexSet(integer: 0))) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .persistenceFailed(message: "削除に失敗しました")
            )
        }
    }

    func test_attachFavoriteGatewayで永続化先を差し替える() throws {
        let first = InMemoryGroupFavoriteGateway()
        try first.insert(GroupFavorite(name: "最初", members: ["A"]))
        let second = InMemoryGroupFavoriteGateway()
        try second.insert(GroupFavorite(name: "差し替え後", members: ["B"]))
        let interactor = FavoriteGroupInteractor(favoriteGateway: first)

        XCTAssertEqual(interactor.allFavorites().map(\.name), ["最初"])

        interactor.attachFavoriteGateway(second)

        XCTAssertEqual(interactor.allFavorites().map(\.name), ["差し替え後"])
    }
}

// MARK: - Presenter

@MainActor
final class FavoriteGroupPresenterTests: XCTestCase {

    private final class OutputSpy: FavoriteGroupModuleOutput {
        var selectedID: FavoriteGroupID?
        var cancelCount = 0

        func favoriteGroupDidSelect(id: FavoriteGroupID) { selectedID = id }
        func favoriteGroupDidCancel() { cancelCount += 1 }
    }

    private func makePresenter(
        gateway: GroupFavoriteGatewayBase,
        output: OutputSpy
    ) -> FavoriteGroupPresenter {
        FavoriteGroupPresenter(
            interactor: FavoriteGroupInteractor(favoriteGateway: gateway),
            output: output
        )
    }

    func test_onAppearで一覧をViewDataに公開する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "同期", members: ["太郎"]))
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)

        presenter.onAppear()

        XCTAssertEqual(presenter.viewData.groups.map(\.name), ["同期"])
        XCTAssertFalse(presenter.viewData.isEmpty)
    }

    func test_空ならisEmptyになる() {
        let presenter = makePresenter(gateway: InMemoryGroupFavoriteGateway(), output: OutputSpy())

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertTrue(presenter.viewData.groups.isEmpty)
    }

    func test_選択はOutputへ通知する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "同期", members: ["太郎"]))
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchAll().first?.id)

        presenter.didSelectGroup(id: id)

        XCTAssertEqual(output.selectedID, id)
    }

    func test_削除は一覧から消す() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(GroupFavorite(name: "古い", members: ["A"]))
        try gateway.insert(GroupFavorite(name: "新しい", members: ["B"]))
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteGroups(at: IndexSet(integer: 0))

        XCTAssertEqual(presenter.viewData.groups.map(\.name), ["古い"])
        XCTAssertNil(presenter.alert)
    }

    func test_削除失敗はアラートになる() {
        let presenter = makePresenter(gateway: FailingDeleteGroupFavoriteGateway(), output: OutputSpy())

        presenter.didDeleteGroups(at: IndexSet(integer: 0))

        XCTAssertEqual(presenter.alert, .deleteFailed(message: "削除に失敗しました"))
    }

    func test_閉じるはOutputへキャンセルを通知する() {
        let output = OutputSpy()
        let presenter = makePresenter(gateway: InMemoryGroupFavoriteGateway(), output: output)

        presenter.didTapClose()

        XCTAssertEqual(output.cancelCount, 1)
    }
}

private final class FailingDeleteGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func fetchAll() throws -> [GroupFavorite] {
        [GroupFavorite(name: "同期", members: ["A"])]
    }

    override func delete(atOffsets offsets: IndexSet, in sortedFavorites: [GroupFavorite]) throws {
        throw NSError(
            domain: "FavoriteGroupTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "削除に失敗しました"]
        )
    }
}
