//
//  AttendeeListInteractorTests.swift
//  SakuttoSeatTests
//
//  refactor_AttendeeList.md Phase 0 / Phase 3
//  追加規則・一括パース・置換・お気に入り上限 / 保存 / 読込を固定する。
//  一覧・削除は FavoriteGroupTests 側。保存結果は fetchSummaries / fetch(id:) で断言する。
//  refactor_groupFavorite.md Phase 0（空メンバー保存は拒まない現状を固定）
//  refactor_groupFavorite.md Phase 2（保存結果の断言は name / memberNames。結合は ViewData）
//  refactor_groupFavorite.md Phase 3（fetchAll は削除。詳細は fetch(id:)）
//  refactor_groupFavorite.md Phase 4（assemble 注入の Gateway は attach / onAppear 前から使う）
//

import XCTest
@testable import SakuttoSeat

final class AttendeeListInteractorTests: XCTestCase {

    private func names(of attendees: [Attendee]) -> [String] {
        attendees.map(\.name)
    }

    // MARK: - 追加

    func test_名前を1人追加できる() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(name: "田中")

        XCTAssertEqual(names(of: attendees), ["田中"])
        XCTAssertEqual(names(of: interactor.allAttendees()), ["田中"])
    }

    func test_前後の空白と改行を除去して追加する() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(name: "  佐藤  \n")

        XCTAssertEqual(names(of: attendees), ["佐藤"])
    }

    func test_空文字や空白のみは追加しない() {
        let interactor = AttendeeListInteractor()

        XCTAssertTrue(interactor.add(name: "").isEmpty)
        XCTAssertTrue(interactor.add(name: "   ").isEmpty)
        XCTAssertTrue(interactor.add(name: "\n\t").isEmpty)
        XCTAssertTrue(interactor.allAttendees().isEmpty)
    }

    func test_同名は連番を付けてユニークにする() {
        let interactor = AttendeeListInteractor()

        _ = interactor.add(name: "田中")
        _ = interactor.add(name: "田中")
        let attendees = interactor.add(name: "田中")

        XCTAssertEqual(names(of: attendees), ["田中", "田中(2)", "田中(3)"])
    }

    // MARK: - 一括追加

    func test_改行と半角全角カンマで分割し空要素をスキップする() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.add(fromText: "太郎\n  花子  ,次郎、\n、 四郎")

        XCTAssertEqual(names(of: attendees), ["太郎", "花子", "次郎", "四郎"])
    }

    func test_一括追加でも同名はユニーク化する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(name: "A")

        let attendees = interactor.add(fromText: "A,B")

        XCTAssertEqual(names(of: attendees), ["A", "A(2)", "B"])
    }

    func test_大量の同名一括追加は連番でユニーク化する() {
        let interactor = AttendeeListInteractor()
        let raw = Array(repeating: "太郎", count: 50).joined(separator: ",")

        let attendees = interactor.add(fromText: raw)

        XCTAssertEqual(attendees.count, 50)
        XCTAssertEqual(attendees.first?.name, "太郎")
        XCTAssertEqual(attendees[1].name, "太郎(2)")
        XCTAssertEqual(attendees.last?.name, "太郎(50)")
        XCTAssertEqual(Set(names(of: attendees)).count, 50)
    }

    func test_既存の連番を避けてユニーク名を付ける() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,A")

        let attendees = interactor.add(fromText: "A,A")

        XCTAssertEqual(names(of: attendees), ["A", "A(2)", "A(3)", "A(4)"])
    }

    // MARK: - 削除

    func test_単一のインデックスを削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C")

        let attendees = interactor.remove(atOffsets: IndexSet(integer: 1))

        XCTAssertEqual(names(of: attendees), ["A", "C"])
    }

    func test_複数のインデックスを一度に削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C,D")

        let attendees = interactor.remove(atOffsets: IndexSet([0, 2]))

        XCTAssertEqual(names(of: attendees), ["B", "D"])
    }

    func test_全員を削除する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B")

        let attendees = interactor.removeAll()

        XCTAssertTrue(attendees.isEmpty)
        XCTAssertTrue(interactor.allAttendees().isEmpty)
    }

    // MARK: - シャッフル

    func test_シャッフルしても要素の集合と件数は変わらない() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "A,B,C,D,E")
        let original = interactor.allAttendees()

        let shuffled = interactor.shuffle()

        XCTAssertEqual(shuffled.count, original.count)
        XCTAssertEqual(Set(names(of: shuffled)), Set(names(of: original)))
        XCTAssertEqual(names(of: interactor.allAttendees()), names(of: shuffled))
    }

    func test_1人以下ではシャッフルしても順序は変わらない() {
        let empty = AttendeeListInteractor()
        XCTAssertTrue(empty.shuffle().isEmpty)

        let single = AttendeeListInteractor()
        _ = single.add(name: "A")
        XCTAssertEqual(names(of: single.shuffle()), ["A"])
    }

    // MARK: - 一括置換

    func test_replaceAllは参加者を完全置換する() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "旧1,旧2")

        let attendees = interactor.replaceAll(names: ["新1", "新2", "新3"])

        XCTAssertEqual(names(of: attendees), ["新1", "新2", "新3"])
        XCTAssertEqual(names(of: interactor.allAttendees()), ["新1", "新2", "新3"])
    }

    func test_replaceAllは空配列でリストを空にする() {
        let interactor = AttendeeListInteractor()
        _ = interactor.add(fromText: "残したくない")

        let attendees = interactor.replaceAll(names: [])

        XCTAssertTrue(attendees.isEmpty)
    }

    func test_replaceAllは空白のみをスキップし同名はユニーク化する() {
        let interactor = AttendeeListInteractor()

        let attendees = interactor.replaceAll(names: ["A", "  ", "A", "B"])

        XCTAssertEqual(names(of: attendees), ["A", "A(2)", "B"])
    }

    // MARK: - お気に入り

    func test_お気に入り保存可否は無料枠3件まで() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(name: "A")

        XCTAssertEqual(interactor.favoriteSaveAvailability(), .available)

        try interactor.saveCurrentAsFavorite(named: "1")
        try interactor.saveCurrentAsFavorite(named: "2")
        try interactor.saveCurrentAsFavorite(named: "3")

        XCTAssertEqual(
            interactor.favoriteSaveAvailability(),
            .limitReached(
                currentCount: FeatureLimit.freeFavoriteGroupCount,
                limit: FeatureLimit.freeFavoriteGroupCount
            )
        )
        XCTAssertThrowsError(try interactor.saveCurrentAsFavorite(named: "4")) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .limitReached(
                    currentCount: FeatureLimit.freeFavoriteGroupCount,
                    limit: FeatureLimit.freeFavoriteGroupCount
                )
            )
        }
    }

    func test_現在の参加者をお気に入りに保存する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(fromText: "太郎,花子")

        try interactor.saveCurrentAsFavorite(named: "  同期  ")

        let summaries = try gateway.fetchSummaries()
        XCTAssertEqual(summaries.count, 1)
        let saved = try XCTUnwrap(summaries.first)
        XCTAssertEqual(saved.name, "同期")
        XCTAssertEqual(try gateway.fetch(id: saved.id)?.memberNames, ["太郎", "花子"])
    }

    func test_参加者空でもお気に入り保存は拒まない() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        XCTAssertTrue(interactor.allAttendees().isEmpty)

        try interactor.saveCurrentAsFavorite(named: "空グループ")

        let summaries = try gateway.fetchSummaries()
        XCTAssertEqual(summaries.count, 1)
        let saved = try XCTUnwrap(summaries.first)
        XCTAssertEqual(saved.name, "空グループ")
        XCTAssertEqual(try gateway.fetch(id: saved.id)?.memberNames, [])
    }

    func test_空白のみのグループ名はinvalidNameになる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(name: "A")

        XCTAssertThrowsError(try interactor.saveCurrentAsFavorite(named: "   ")) { error in
            XCTAssertEqual(error as? FavoriteSaveError, .invalidName)
        }
        XCTAssertTrue(try gateway.fetchSummaries().isEmpty)
    }

    func test_保存失敗はpersistenceFailedになる() {
        let interactor = AttendeeListInteractor(favoriteGateway: FailingInsertGroupFavoriteGateway())
        _ = interactor.add(name: "A")

        XCTAssertThrowsError(try interactor.saveCurrentAsFavorite(named: "同期")) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .persistenceFailed(message: "書き込みに失敗しました")
            )
        }
    }

    func test_お気に入り読込で参加者リストを置換する() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "新メンバ", members: ["新1", "新2", "新3"])
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(fromText: "旧1,旧2")
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        let loaded = try interactor.loadFavorite(id: id)

        XCTAssertEqual(names(of: loaded), ["新1", "新2", "新3"])
        XCTAssertEqual(names(of: interactor.allAttendees()), ["新1", "新2", "新3"])
    }

    func test_メンバーが空のお気に入りを読むとリストが空になる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        try gateway.insert(name: "空", members: [])
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(name: "残したくない")
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        let loaded = try interactor.loadFavorite(id: id)

        XCTAssertTrue(loaded.isEmpty)
    }

    func test_お気に入り読込の永続化失敗はpersistenceFailedになる() {
        let interactor = AttendeeListInteractor(favoriteGateway: FailingFetchGroupFavoriteGateway())

        XCTAssertThrowsError(try interactor.loadFavorite(id: UUID())) { error in
            XCTAssertEqual(
                error as? FavoriteSaveError,
                .persistenceFailed(message: "読み込みに失敗しました")
            )
        }
    }

    func test_存在しないお気に入りの読込はnotFoundになる() {
        let interactor = AttendeeListInteractor()

        XCTAssertThrowsError(try interactor.loadFavorite(id: UUID())) { error in
            XCTAssertEqual(error as? FavoriteSaveError, .notFound)
        }
    }

    func test_initで渡したGatewayはattachなしで保存に使われる() throws {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)
        _ = interactor.add(name: "A")

        try interactor.saveCurrentAsFavorite(named: "起動直後")

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["起動直後"])
    }

    func test_attachFavoriteGatewayで永続化先を差し替える() throws {
        let first = InMemoryGroupFavoriteGateway()
        let second = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: first)
        _ = interactor.add(name: "A")
        try interactor.saveCurrentAsFavorite(named: "最初")

        interactor.attachFavoriteGateway(second)
        try interactor.saveCurrentAsFavorite(named: "差し替え後")

        XCTAssertEqual(try first.fetchSummaries().map(\.name), ["最初"])
        XCTAssertEqual(try second.fetchSummaries().map(\.name), ["差し替え後"])
    }

    func test_currentFavoriteGatewayはinitで渡したインスタンスを返す() {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor(favoriteGateway: gateway)

        XCTAssertTrue(interactor.currentFavoriteGateway() === gateway)
    }

    func test_currentFavoriteGatewayはattachしたインスタンスを返す() {
        let gateway = InMemoryGroupFavoriteGateway()
        let interactor = AttendeeListInteractor()

        interactor.attachFavoriteGateway(gateway)

        XCTAssertTrue(interactor.currentFavoriteGateway() === gateway)
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

/// fetch(id:) だけ失敗させるテスト用 Gateway
private final class FailingFetchGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? {
        throw NSError(
            domain: "AttendeeListTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }
}
