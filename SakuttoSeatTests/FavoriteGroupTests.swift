//
//  FavoriteGroupTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 5（お気に入り一覧子モジュールの回帰）
//  refactor_favorite.md Phase 0 / Phase 1（attach は Interactor のみ）
//  refactor_favorite.md Phase 2 / Phase 3（ID 削除・Snapshot 戻り）
//  refactor_favorite.md Phase 5（Copy.edit。行 UI は View の SavedListRow）
//  refactor_favorite.md Phase 6（閉じる / 編集 / 空状態の A11y Copy）
//  refactor_groupFavorite.md Phase 2（memberSummary 断言は ViewData Builder）
//  refactor_groupFavorite.md Phase 3（一覧は Summary。Gateway 直読みは fetchSummaries）
//  refactor_groupFavorite.md Phase 4（onAppear は再 fetch しない。init で公開済み）
//  refactor_groupFavorite.md Phase 5（失敗ダブルは Support/GroupFavoriteTestGateways）
//

import XCTest
@testable import SakuttoSeat

// MARK: - Interactor

final class FavoriteGroupInteractorTests: XCTestCase {

    func test_一覧は新しい順のSummaryを返す() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "新しい", members: ["B", "C"])
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)

        let groups = try interactor.allFavorites()

        XCTAssertEqual(groups.map(\.name), ["新しい", "古い"])
        XCTAssertEqual(groups.first?.memberSummary, "B, C")
    }

    func test_ID指定で削除する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "新しい", members: ["B"])
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)
        let newerID = try XCTUnwrap(interactor.allFavorites().first?.id)

        try interactor.deleteFavorites(ids: [newerID])

        XCTAssertEqual(try interactor.allFavorites().map(\.name), ["古い"])
    }

    func test_削除失敗はpersistenceFailedになる() {
        let interactor = FavoriteGroupInteractor(favoriteGateway: FailingDeleteGroupFavoriteGateway())

        XCTAssertThrowsError(try interactor.deleteFavorites(ids: [UUID()])) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .persistenceFailed(message: "削除に失敗しました")
            )
        }
    }

    func test_attachFavoriteGatewayで永続化先を差し替える() throws {
        let first = InMemoryGroupFavoriteGateway()
        try first.insert(name: "最初", members: ["A"])
        let second = InMemoryGroupFavoriteGateway()
        try second.insert(name: "差し替え後", members: ["B"])
        let interactor = FavoriteGroupInteractor(favoriteGateway: first)

        XCTAssertEqual(try interactor.allFavorites().map(\.name), ["最初"])

        interactor.attachFavoriteGateway(second)

        XCTAssertEqual(try interactor.allFavorites().map(\.name), ["差し替え後"])
    }

    func test_複数IDで削除する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "真ん中", members: ["B"])
        try gateway.insert(name: "新しい", members: ["C"])
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)
        let groups = try interactor.allFavorites()

        try interactor.deleteFavorites(ids: [groups[0].id, groups[2].id])

        XCTAssertEqual(try interactor.allFavorites().map(\.name), ["真ん中"])
    }

    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "残る", members: ["A"])
        let interactor = FavoriteGroupInteractor(favoriteGateway: gateway)

        try interactor.deleteFavorites(ids: [UUID()])

        XCTAssertEqual(try interactor.allFavorites().map(\.name), ["残る"])
    }

    func test_取得失敗はpersistenceFailedになる() {
        let interactor = FavoriteGroupInteractor(favoriteGateway: FailingFetchGroupFavoriteGateway())

        XCTAssertThrowsError(try interactor.allFavorites()) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .persistenceFailed(message: "読み込みに失敗しました")
            )
        }
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

    func test_initで一覧をViewDataのRowに公開する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "同期", members: ["太郎"])
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["同期"])
        XCTAssertEqual(presenter.viewData.rows.map(\.memberSummary), ["太郎"])
        XCTAssertFalse(presenter.viewData.isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_空ならisEmptyになる() {
        let presenter = makePresenter(gateway: InMemoryGroupFavoriteGateway(), output: OutputSpy())

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertTrue(presenter.viewData.rows.isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_選択はOutputへ通知する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "同期", members: ["太郎"])
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.didSelectGroup(id: id)

        XCTAssertEqual(output.selectedID, id)
    }

    func test_選択はGatewayとViewDataを変えずOutputだけに通知する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "同期", members: ["太郎"])
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.didSelectGroup(id: id)

        XCTAssertEqual(output.selectedID, id)
        XCTAssertEqual(output.cancelCount, 0)
        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["同期"])
        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["同期"])
        XCTAssertNil(presenter.route)
    }

    func test_取得失敗は空のViewDataとloadFailedのRouteになる() {
        let presenter = makePresenter(
            gateway: FailingFetchGroupFavoriteGateway(),
            output: OutputSpy()
        )

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertTrue(presenter.viewData.rows.isEmpty)
        XCTAssertEqual(
            presenter.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )
    }

    func test_削除は一覧から消す() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "古い", members: ["A"])
        try gateway.insert(name: "新しい", members: ["B"])
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteGroups(at: IndexSet(integer: 0))

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["古い"])
        XCTAssertNil(presenter.route)
    }

    func test_範囲外offsetの削除は一覧を変えない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "残る", members: ["A"])
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteGroups(at: IndexSet(integer: 5))

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["残る"])
        XCTAssertNil(presenter.route)
    }

    func test_削除失敗はdeleteFailedのRouteになる() {
        let presenter = makePresenter(gateway: FailingDeleteGroupFavoriteGateway(), output: OutputSpy())

        presenter.didDeleteGroups(at: IndexSet(integer: 0))

        XCTAssertEqual(
            presenter.route,
            .alert(.deleteFailed(message: "削除に失敗しました"))
        )
    }

    func test_dismissRouteで提示を閉じる() {
        let presenter = makePresenter(
            gateway: FailingFetchGroupFavoriteGateway(),
            output: OutputSpy()
        )
        XCTAssertNotNil(presenter.route)

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
    }

    func test_閉じるはOutputへキャンセルを通知する() {
        let output = OutputSpy()
        let presenter = makePresenter(gateway: InMemoryGroupFavoriteGateway(), output: output)

        presenter.didTapClose()

        XCTAssertEqual(output.cancelCount, 1)
    }
}

// MARK: - Copy

final class FavoriteGroupCopyTests: XCTestCase {
    func test_文言は既存Catalogキーのまま() {
        XCTAssertEqual(FavoriteGroupCopy.navigationTitle, "お気に入りグループ")
        XCTAssertEqual(FavoriteGroupCopy.emptyMessage, "登録されているグループはありません")
        XCTAssertEqual(FavoriteGroupCopy.selectAccessibilityHint, "このグループを参加者リストに読み込みます")
        XCTAssertEqual(FavoriteGroupCopy.edit, "編集")
        XCTAssertEqual(FavoriteGroupCopy.close, "閉じる")
        XCTAssertEqual(FavoriteGroupCopy.ok, "OK")
        XCTAssertEqual(FavoriteGroupCopy.deleteFailedTitle, "削除に失敗しました")
        XCTAssertEqual(FavoriteGroupCopy.loadFailedTitle, "読み込みに失敗しました")
    }

    func test_閉じる編集空状態のHintは親シート導線と対になる() {
        XCTAssertEqual(FavoriteGroupCopy.closeAccessibilityHint, "保存済みグループの一覧を閉じます")
        XCTAssertEqual(FavoriteGroupCopy.editAccessibilityHint, "グループを削除できるようにします")
        XCTAssertEqual(FavoriteGroupCopy.done, "完了")
        XCTAssertEqual(FavoriteGroupCopy.doneAccessibilityHint, "編集を終了します")
        XCTAssertEqual(FavoriteGroupCopy.emptyAccessibilityHint, "閉じるボタンで参加者リストに戻ります")
        XCTAssertEqual(FavoriteGroupCopy.editingSelectDisabledHint, "編集中は読み込みできません")
    }

    func test_行のHintは編集中に読み込み案内を出さない() {
        XCTAssertEqual(
            FavoriteGroupCopy.rowAccessibilityHint(isEditing: false),
            "このグループを参加者リストに読み込みます"
        )
        XCTAssertEqual(
            FavoriteGroupCopy.rowAccessibilityHint(isEditing: true),
            "編集中は読み込みできません"
        )
    }

    func test_編集トグルのLabelとHintは完了時に切り替わる() {
        XCTAssertEqual(FavoriteGroupCopy.editAccessibilityLabel(isEditing: false), "編集")
        XCTAssertEqual(FavoriteGroupCopy.editAccessibilityLabel(isEditing: true), "完了")
        XCTAssertEqual(
            FavoriteGroupCopy.editButtonAccessibilityHint(isEditing: false),
            "グループを削除できるようにします"
        )
        XCTAssertEqual(
            FavoriteGroupCopy.editButtonAccessibilityHint(isEditing: true),
            "編集を終了します"
        )
    }

    func test_失敗アラートのタイトルはCatalogにある() {
        XCTAssertEqual(FavoriteGroupCopy.deleteFailedTitle, String(localized: "削除に失敗しました"))
        XCTAssertEqual(FavoriteGroupCopy.loadFailedTitle, String(localized: "読み込みに失敗しました"))
    }
}

// MARK: - ViewData

final class FavoriteGroupViewDataTests: XCTestCase {
    func test_BuilderはSummaryのmemberSummaryをRowへ写す() {
        XCTAssertEqual(FavoriteGroupViewDataBuilder.build(groups: []), .empty)

        let emptyMembers = FavoriteGroupSummary(id: UUID(), name: "空", memberSummary: "")
        let emptyData = FavoriteGroupViewDataBuilder.build(groups: [emptyMembers])
        XCTAssertEqual(emptyData.rows.map(\.name), ["空"])
        XCTAssertEqual(emptyData.rows.map(\.memberSummary), [""])
        XCTAssertFalse(emptyData.isEmpty)

        let one = FavoriteGroupSummary(id: UUID(), name: "同期", memberSummary: "太郎")
        let oneData = FavoriteGroupViewDataBuilder.build(groups: [one])
        XCTAssertEqual(oneData.rows.map(\.id), [one.id])
        XCTAssertEqual(oneData.rows.map(\.memberSummary), ["太郎"])

        let many = FavoriteGroupSummary(
            id: UUID(),
            name: "同期",
            memberSummary: "太郎, 花子, 次郎"
        )
        let manyData = FavoriteGroupViewDataBuilder.build(groups: [many])
        XCTAssertEqual(manyData.rows.map(\.memberSummary), ["太郎, 花子, 次郎"])
    }
}
