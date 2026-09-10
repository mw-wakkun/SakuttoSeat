//
//  SeatingChartPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 0（準備と回帰テスト）
//

import XCTest
import SwiftData
@testable import SakuttoSeat

/// 空の `SeatingChartRouterProtocol` に対するテストダブル。
/// Phase 4 で Router が実体を持つ際は、呼び出し記録を持つスパイに拡張する。
private final class SeatingChartRouterSpy: SeatingChartRouterProtocol {}

/// `SeatingChartPresenter` に現在置かれているドメインロジックの挙動を固定する回帰テスト。
///
/// Phase 3 でこれらのロジックを `SeatingChartInteractor` へ移送するため、
/// 移送後は同じ期待値のまま Interactor 直接呼び出しへ書き換えて green を維持すること。
@MainActor
final class SeatingChartPresenterTests: XCTestCase {

    // MARK: - ヘルパー

    private func makePresenter(
        attendeeNames: [String]
    ) -> (presenter: SeatingChartPresenter, attendees: [Attendee]) {
        let attendees = attendeeNames.map { Attendee(name: $0) }
        let presenter = SeatingChartPresenter(
            interactor: SeatingChartInteractor(),
            router: SeatingChartRouterSpy(),
            attendees: attendees
        )
        return (presenter, attendees)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SeatingLayoutTemplate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func assignedIDs(_ presenter: SeatingChartPresenter) -> Set<UUID> {
        Set(presenter.tables.flatMap { $0.assignedMembers.map(\.id) })
    }

    // MARK: - テーブル名の払い出し規則

    func test_テーブル名は26進数のように連番で生成される() {
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 0), "テーブルA")
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 25), "テーブルZ")
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 26), "テーブルAA")
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 27), "テーブルAB")
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 51), "テーブルAZ")
        XCTAssertEqual(SeatingChartPresenter.tableName(at: 52), "テーブルBA")
    }

    // MARK: - 初期テーブル生成

    func test_初期化_参加者数から必要なテーブル数が算出される() {
        let (presenter, attendees) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        // 既定定員 4 なので ceil(5 / 4) = 2 テーブル
        XCTAssertEqual(presenter.tables.count, 2)
        XCTAssertEqual(presenter.tables.map(\.name), ["テーブルA", "テーブルB"])
        XCTAssertTrue(presenter.tables.allSatisfy { $0.capacity == 4 && $0.columnCount == 2 })
        XCTAssertEqual(presenter.tables[0].assignedMembers.map(\.name), ["A", "B", "C", "D"])
        XCTAssertEqual(presenter.tables[1].assignedMembers.map(\.name), ["E"])
        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
    }

    func test_初期化_参加者が0人でもテーブルは1つ作られる() {
        let (presenter, _) = makePresenter(attendeeNames: [])

        XCTAssertEqual(presenter.tables.count, 1)
        XCTAssertTrue(presenter.tables[0].assignedMembers.isEmpty)
    }

    // MARK: - テーブル追加

    func test_テーブル追加_列数は定員を超えないようクランプされる() {
        let (presenter, _) = makePresenter(attendeeNames: ["A"])

        presenter.addTable(capacity: 3, columnCount: 5)

        XCTAssertEqual(presenter.tables.last?.capacity, 3)
        XCTAssertEqual(presenter.tables.last?.columnCount, 3)
    }

    func test_テーブル追加_定員と列数が0以下なら1に補正される() {
        let (presenter, _) = makePresenter(attendeeNames: ["A"])

        presenter.addTable(capacity: 0, columnCount: 0)

        XCTAssertEqual(presenter.tables.last?.capacity, 1)
        XCTAssertEqual(presenter.tables.last?.columnCount, 1)
    }

    func test_テーブル追加_未使用の名前が先頭から払い出される() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        presenter.addTable()

        XCTAssertEqual(presenter.tables.map(\.name), ["テーブルA", "テーブルB", "テーブルC"])
    }

    func test_テーブル削除後は空いた名前が再利用される() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C"])
        presenter.addTable()
        XCTAssertEqual(presenter.tables.map(\.name), ["テーブルA", "テーブルB"])

        presenter.deleteTable(id: presenter.tables[0].id)
        XCTAssertEqual(presenter.tables.map(\.name), ["テーブルB"])

        presenter.addTable()

        // 空いた「テーブルA」が先頭から探索されて再利用される
        XCTAssertEqual(presenter.tables.map(\.name), ["テーブルB", "テーブルA"])
    }

    // MARK: - テーブル削除

    func test_テーブル削除_残ったテーブルへ参加者が再割り当てされる() {
        let (presenter, attendees) = makePresenter(attendeeNames: ["A", "B", "C"])
        presenter.addTable()

        presenter.deleteTable(id: presenter.tables[1].id)

        XCTAssertEqual(presenter.tables.count, 1)
        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
    }

    // MARK: - テーブル更新

    func test_テーブル更新_名前と会場レイアウトが反映され列数はクランプされる() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B"])

        presenter.updateTable(
            id: presenter.tables[0].id,
            newName: "幹事席",
            newCapacity: 2,
            newColumnCount: 9,
            newLayoutDirection: .top,
            newLayoutText: "ステージ側"
        )

        XCTAssertEqual(presenter.tables[0].name, "幹事席")
        XCTAssertEqual(presenter.tables[0].capacity, 2)
        XCTAssertEqual(presenter.tables[0].columnCount, 2)
        XCTAssertEqual(presenter.tables[0].layoutDirection, .top)
        XCTAssertEqual(presenter.tables[0].layoutText, "ステージ側")
    }

    func test_テーブル更新_定員変更で不要になった空テーブルは末尾から削除される() {
        let (presenter, attendees) = makePresenter(attendeeNames: ["A", "B", "C"])
        presenter.addTable()
        presenter.addTable()
        XCTAssertEqual(presenter.tables.count, 3)

        let triggerBefore = presenter.scrollToTopTrigger

        presenter.updateTable(
            id: presenter.tables[0].id,
            newName: "テーブルA",
            newCapacity: 3,
            newColumnCount: 2,
            newLayoutDirection: .none,
            newLayoutText: ""
        )

        // 3 人全員が 1 テーブルに収まるため、空になった 2 テーブルが削除される
        XCTAssertEqual(presenter.tables.count, 1)
        XCTAssertEqual(presenter.tables[0].capacity, 3)
        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
        // 保存完了後は最上部へスクロールするトリガーが進む
        XCTAssertEqual(presenter.scrollToTopTrigger, triggerBefore + 1)
    }

    func test_テーブル更新_定員が変わらない場合はテーブル構成が維持される() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C"])
        presenter.addTable()
        XCTAssertEqual(presenter.tables.count, 2)

        presenter.updateTable(
            id: presenter.tables[0].id,
            newName: "改名のみ",
            newCapacity: presenter.tables[0].capacity,
            newColumnCount: 2,
            newLayoutDirection: .none,
            newLayoutText: ""
        )

        // 定員が変わらないため再割り当ても空テーブル削除も行われない
        XCTAssertEqual(presenter.tables.count, 2)
        XCTAssertEqual(presenter.tables[0].name, "改名のみ")
    }

    // MARK: - 一括適用

    func test_一括適用_全テーブルの定員と列数が統一され不足分が追加される() {
        let (presenter, attendees) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        presenter.updateAllTables(
            editingTableId: presenter.tables[0].id,
            newName: "幹事席",
            newCapacity: 2,
            newColumnCount: 5,
            newLayoutDirection: .top,
            newLayoutText: "ステージ側"
        )

        // 定員 2 に統一すると総座席 4 < 参加者 5 のため 1 テーブル追加される
        XCTAssertEqual(presenter.tables.count, 3)
        XCTAssertTrue(presenter.tables.allSatisfy { $0.capacity == 2 && $0.columnCount == 2 })
        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
    }

    func test_一括適用_名前と会場レイアウトは編集中のテーブルにだけ反映される() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        presenter.updateAllTables(
            editingTableId: presenter.tables[0].id,
            newName: "幹事席",
            newCapacity: 4,
            newColumnCount: 2,
            newLayoutDirection: .top,
            newLayoutText: "ステージ側"
        )

        XCTAssertEqual(presenter.tables[0].name, "幹事席")
        XCTAssertEqual(presenter.tables[0].layoutDirection, .top)
        XCTAssertEqual(presenter.tables[0].layoutText, "ステージ側")
        XCTAssertEqual(presenter.tables[1].layoutDirection, .none)
        XCTAssertEqual(presenter.tables[1].layoutText, "")
    }

    func test_一括適用で改名すると空いた名前が追加テーブルに再利用される_既知の課題() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        presenter.updateAllTables(
            editingTableId: presenter.tables[0].id,
            newName: "幹事席",
            newCapacity: 2,
            newColumnCount: 2,
            newLayoutDirection: .none,
            newLayoutText: ""
        )

        // 「テーブルA」が改名で未使用になるため、末尾に追加されたテーブルがその名前を拾う。
        // 結果として並び順と名前の昇順が一致しなくなる。
        XCTAssertEqual(presenter.tables.map(\.name), ["幹事席", "テーブルB", "テーブルA"])
    }

    func test_一括適用後に追加するテーブルは同じ定員と列数を引き継ぐ() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B"])

        presenter.updateAllTables(
            editingTableId: presenter.tables[0].id,
            newName: "卓",
            newCapacity: 6,
            newColumnCount: 3,
            newLayoutDirection: .none,
            newLayoutText: ""
        )
        presenter.addTable()

        XCTAssertEqual(presenter.tables.last?.capacity, 6)
        XCTAssertEqual(presenter.tables.last?.columnCount, 3)
    }

    // MARK: - ロック

    func test_ロック切替は指定した座席にだけ作用する() {
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B"])
        let tableID = presenter.tables[0].id
        let memberID = presenter.tables[0].assignedMembers[0].id

        XCTAssertFalse(presenter.tables[0].assignedMembers[0].isLocked)

        presenter.toggleLock(tableId: tableID, memberId: memberID)
        XCTAssertTrue(presenter.tables[0].assignedMembers[0].isLocked)
        XCTAssertFalse(presenter.tables[0].assignedMembers[1].isLocked)

        presenter.toggleLock(tableId: tableID, memberId: memberID)
        XCTAssertFalse(presenter.tables[0].assignedMembers[0].isLocked)
    }

    // MARK: - シャッフル

    func test_シャッフルしても全参加者が保持される() {
        let (presenter, attendees) = makePresenter(attendeeNames: (1...12).map { "参加者\($0)" })

        presenter.shuffle()

        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
    }

    // MARK: - テンプレート適用

    func test_テンプレート適用_レイアウトが復元され会場列数が返される() {
        let (presenter, attendees) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E", "F"])
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        let restoredColumnCount = presenter.applyTemplate(template)

        XCTAssertEqual(restoredColumnCount, 4)
        XCTAssertEqual(presenter.tables.map(\.name), ["受付卓", "奥卓"])
        XCTAssertTrue(presenter.tables.allSatisfy { $0.capacity == 3 && $0.columnCount == 3 })
        XCTAssertEqual(presenter.tables[0].layoutDirection, .left)
        XCTAssertEqual(presenter.tables[1].layoutText, "窓際")
        XCTAssertEqual(assignedIDs(presenter), Set(attendees.map(\.id)))
        XCTAssertEqual(presenter.scrollToTopTrigger, 1)
    }

    func test_テンプレート適用_全テーブルが同一構成なら以降の既定値も揃う() {
        let (presenter, _) = makePresenter(attendeeNames: ["A"])
        let template = SeatingLayoutTemplate(
            name: "均一レイアウト",
            tables: [TableTemplate(name: "卓1", capacity: 5, columnCount: 5, layoutDirection: .none, layoutText: "")],
            globalColumnCount: 2
        )

        _ = presenter.applyTemplate(template)
        presenter.addTable()

        XCTAssertEqual(presenter.tables.last?.capacity, 5)
        XCTAssertEqual(presenter.tables.last?.columnCount, 5)
    }

    // MARK: - テンプレート保存（現状は Presenter が ModelContext を直接操作する）

    func test_テンプレート保存_無料枠は3件までで4件目から保存不可になる() throws {
        let context = try makeInMemoryContext()
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B"])

        XCTAssertTrue(presenter.canSaveTemplate(context: context))

        presenter.saveLayoutAsTemplate(templateName: "1件目", globalColumnCount: 2, context: context)
        presenter.saveLayoutAsTemplate(templateName: "2件目", globalColumnCount: 2, context: context)
        XCTAssertTrue(presenter.canSaveTemplate(context: context))

        presenter.saveLayoutAsTemplate(templateName: "3件目", globalColumnCount: 2, context: context)
        XCTAssertFalse(presenter.canSaveTemplate(context: context))

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertEqual(saved.count, 3)
    }

    func test_テンプレート保存_現在のレイアウトと会場列数が保存される() throws {
        let context = try makeInMemoryContext()
        let (presenter, _) = makePresenter(attendeeNames: ["A", "B", "C", "D", "E"])

        presenter.saveLayoutAsTemplate(templateName: "歓迎会", globalColumnCount: 3, context: context)

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].name, "歓迎会")
        XCTAssertEqual(saved[0].globalColumnCount, 3)
        // レイアウト情報のみが保存され、参加者は含まれない
        XCTAssertEqual(saved[0].tables.count, 2)
        XCTAssertEqual(saved[0].tables.map(\.capacity), [4, 4])
        XCTAssertEqual(saved[0].tables.map(\.name), ["テーブルA", "テーブルB"])
    }

    func test_テンプレート保存_名前が空白のみなら保存されない() throws {
        let context = try makeInMemoryContext()
        let (presenter, _) = makePresenter(attendeeNames: ["A"])

        presenter.saveLayoutAsTemplate(templateName: "   ", globalColumnCount: 2, context: context)

        let saved = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        XCTAssertTrue(saved.isEmpty)
    }
}
