//
//  SeatingChartInteractorTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 3（Presenter から移送したドメインロジックの回帰）
//

import XCTest
@testable import SakuttoSeat

/// `SeatingChartInteractor` の挙動を固定する回帰テスト。
///
/// `_既知の課題` が付いたテストは是正対象の挙動を意図的に固定しているため、
/// Phase 6 で挙動を変更する際はテスト側も同時に更新してください。
@MainActor
final class SeatingChartInteractorTests: XCTestCase {

    // MARK: - ヘルパー

    private func makeAttendees(_ names: [String]) -> [Attendee] {
        names.map { Attendee(name: $0) }
    }

    private func makeInteractor(
        names: [String],
        featureUnlock: FeatureUnlockState? = nil,
        templateGateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway()
    ) -> SeatingChartInteractor {
        SeatingChartInteractor(
            attendees: makeAttendees(names),
            featureUnlock: featureUnlock,
            templateGateway: templateGateway
        )
    }

    private func makeTable(
        capacity: Int,
        columnCount: Int = 2,
        members: [SeatingMember] = []
    ) -> SeatingTable {
        SeatingTable(
            name: "テーブル",
            capacity: capacity,
            columnCount: columnCount,
            layoutDirection: .none,
            layoutText: "",
            assignedMembers: members
        )
    }

    private func assignedNames(_ tables: [SeatingTable]) -> [[String]] {
        tables.map { $0.assignedMembers.map(\.name) }
    }

    private func assignedIDs(_ tables: [SeatingTable]) -> Set<UUID> {
        Set(tables.flatMap { $0.assignedMembers.map(\.id) })
    }

    private func tableUpdate(
        id: TableID,
        name: String,
        capacity: Int,
        columnCount: Int,
        layoutDirection: LayoutDirection = .none,
        layoutText: String = "",
        applyToAll: Bool = false
    ) -> TableUpdateRequest {
        TableUpdateRequest(
            tableID: id,
            name: name,
            capacity: capacity,
            columnCount: columnCount,
            layoutDirection: layoutDirection,
            layoutText: layoutText,
            applyToAll: applyToAll
        )
    }

    // MARK: - 登録順の割り当て

    func test_登録順割り当て_定員内なら登録順のまま配置される() {
        let attendees = makeAttendees(["A", "B", "C"])
        let tables = [makeTable(capacity: 4)]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B", "C"])
        XCTAssertEqual(result[0].assignedMembers.map(\.id), attendees.map(\.id))
    }

    func test_登録順割り当て_複数テーブルへ定員ぶんずつ順に詰められる() {
        let attendees = makeAttendees(["A", "B", "C", "D", "E"])
        let tables = [makeTable(capacity: 2), makeTable(capacity: 2), makeTable(capacity: 2)]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(assignedNames(result), [["A", "B"], ["C", "D"], ["E"]])
    }

    func test_登録順割り当て_参加者が0人なら全テーブルが空席になる() {
        let tables = [makeTable(capacity: 4), makeTable(capacity: 4)]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: [], to: tables)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.assignedMembers.isEmpty })
    }

    func test_登録順割り当て_既存の未ロック席は破棄されて再構築される() {
        let attendees = makeAttendees(["A", "B"])
        let existing = [
            SeatingMember(id: attendees[1].id, name: "B"),
            SeatingMember(id: attendees[0].id, name: "A")
        ]
        let tables = [makeTable(capacity: 2, members: existing)]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
    }

    func test_登録順割り当て_総座席数が参加者数より少ないとあふれた参加者は配置されない_既知の課題() {
        let attendees = makeAttendees(["A", "B", "C"])
        let tables = [makeTable(capacity: 2)]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertFalse(assignedIDs(result).contains(attendees[2].id))
    }

    // MARK: - シャッフル

    func test_シャッフル_座席数が足りていれば全参加者が保持される() {
        let attendees = makeAttendees((1...10).map { "参加者\($0)" })
        let tables = [makeTable(capacity: 4), makeTable(capacity: 4), makeTable(capacity: 4)]

        let result = SeatingChartInteractor().shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertEqual(assignedIDs(result), Set(attendees.map(\.id)))
    }

    func test_シャッフル_ロック席は同じテーブルの同じ位置に維持される() {
        let attendees = makeAttendees(["A", "B", "C", "D"])
        let tables = [
            makeTable(capacity: 2, members: [
                SeatingMember(id: attendees[0].id, name: "A", isLocked: true),
                SeatingMember(id: attendees[1].id, name: "B")
            ]),
            makeTable(capacity: 2, members: [
                SeatingMember(id: attendees[2].id, name: "C"),
                SeatingMember(id: attendees[3].id, name: "D")
            ])
        ]

        for _ in 0..<20 {
            let result = SeatingChartInteractor().shuffleAndAssign(attendees: attendees, to: tables)

            XCTAssertEqual(result[0].assignedMembers.first?.name, "A")
            XCTAssertEqual(result[0].assignedMembers.first?.isLocked, true)
            XCTAssertEqual(assignedIDs(result), Set(attendees.map(\.id)))
        }
    }

    func test_シャッフル_全席ロック済みなら配置は変わらない() {
        let attendees = makeAttendees(["A", "B"])
        let tables = [makeTable(capacity: 2, members: [
            SeatingMember(id: attendees[0].id, name: "A", isLocked: true),
            SeatingMember(id: attendees[1].id, name: "B", isLocked: true)
        ])]

        let result = SeatingChartInteractor().shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertTrue(result[0].assignedMembers.allSatisfy(\.isLocked))
    }

    func test_シャッフル_未ロック席のロック状態はfalseで再生成される() {
        let attendees = makeAttendees(["A", "B"])
        let tables = [makeTable(capacity: 2, members: [
            SeatingMember(id: attendees[0].id, name: "A", isLocked: false),
            SeatingMember(id: attendees[1].id, name: "B", isLocked: false)
        ])]

        let result = SeatingChartInteractor().shuffleAndAssign(attendees: attendees, to: tables)

        XCTAssertTrue(result[0].assignedMembers.allSatisfy { $0.isLocked == false })
    }

    // MARK: - 既知の課題（Phase 6 で是正予定）

    func test_定員より後ろの座席がロックされていると参加者が消える_既知の課題() {
        let attendees = makeAttendees(["A", "B", "C", "D"])
        var table = makeTable(capacity: 4, members: [
            SeatingMember(id: attendees[0].id, name: "A"),
            SeatingMember(id: attendees[1].id, name: "B"),
            SeatingMember(id: attendees[2].id, name: "C"),
            SeatingMember(id: attendees[3].id, name: "D", isLocked: true)
        ])
        table.capacity = 2

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: [table])

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A", "B"])
        XCTAssertFalse(assignedIDs(result).contains(attendees[3].id))
    }

    func test_ロック席より前の座席が埋まらないと位置が前詰めされる_既知の課題() {
        let attendees = makeAttendees(["A"])
        let tables = [makeTable(capacity: 4, members: [
            SeatingMember(id: UUID(), name: "空"),
            SeatingMember(id: UUID(), name: "空"),
            SeatingMember(id: attendees[0].id, name: "A", isLocked: true)
        ])]

        let result = SeatingChartInteractor().assignInRegistrationOrder(attendees: attendees, to: tables)

        XCTAssertEqual(result[0].assignedMembers.map(\.name), ["A"])
    }

    // MARK: - テーブル名の払い出し規則

    func test_テーブル名は26進数のように連番で生成される() {
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 0), "テーブルA")
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 25), "テーブルZ")
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 26), "テーブルAA")
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 27), "テーブルAB")
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 51), "テーブルAZ")
        XCTAssertEqual(SeatingChartInteractor.tableName(at: 52), "テーブルBA")
    }

    // MARK: - 初期テーブル生成

    func test_初期化_参加者数から必要なテーブル数が算出される() {
        let attendees = makeAttendees(["A", "B", "C", "D", "E"])
        let interactor = SeatingChartInteractor(attendees: attendees)
        let tables = interactor.currentTables()

        XCTAssertEqual(tables.count, 2)
        XCTAssertEqual(tables.map(\.name), ["テーブルA", "テーブルB"])
        XCTAssertTrue(tables.allSatisfy { $0.capacity == 4 && $0.columnCount == 2 })
        XCTAssertEqual(tables[0].assignedMembers.map(\.name), ["A", "B", "C", "D"])
        XCTAssertEqual(tables[1].assignedMembers.map(\.name), ["E"])
        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    func test_初期化_参加者が0人でもテーブルは1つ作られる() {
        let tables = SeatingChartInteractor(attendees: []).currentTables()

        XCTAssertEqual(tables.count, 1)
        XCTAssertTrue(tables[0].assignedMembers.isEmpty)
    }

    // MARK: - テーブル追加

    func test_テーブル追加_列数は定員を超えないようクランプされる() {
        let interactor = makeInteractor(names: ["A"])

        let tables = interactor.addTable(capacity: 3, columnCount: 5)

        XCTAssertEqual(tables.last?.capacity, 3)
        XCTAssertEqual(tables.last?.columnCount, 3)
    }

    func test_テーブル追加_定員と列数が0以下なら1に補正される() {
        let interactor = makeInteractor(names: ["A"])

        let tables = interactor.addTable(capacity: 0, columnCount: 0)

        XCTAssertEqual(tables.last?.capacity, 1)
        XCTAssertEqual(tables.last?.columnCount, 1)
    }

    func test_テーブル追加_未使用の名前が先頭から払い出される() {
        let interactor = makeInteractor(names: ["A", "B", "C", "D", "E"])

        let tables = interactor.addTable()

        XCTAssertEqual(tables.map(\.name), ["テーブルA", "テーブルB", "テーブルC"])
    }

    func test_テーブル削除後は空いた名前が再利用される() {
        let interactor = makeInteractor(names: ["A", "B", "C"])
        _ = interactor.addTable()
        XCTAssertEqual(interactor.currentTables().map(\.name), ["テーブルA", "テーブルB"])

        _ = interactor.deleteTable(id: interactor.currentTables()[0].id)
        XCTAssertEqual(interactor.currentTables().map(\.name), ["テーブルB"])

        _ = interactor.addTable()

        XCTAssertEqual(interactor.currentTables().map(\.name), ["テーブルB", "テーブルA"])
    }

    // MARK: - テーブル削除

    func test_テーブル削除_残ったテーブルへ参加者が再割り当てされる() {
        let attendees = makeAttendees(["A", "B", "C"])
        let interactor = SeatingChartInteractor(attendees: attendees)
        _ = interactor.addTable()

        let tables = interactor.deleteTable(id: interactor.currentTables()[1].id)

        XCTAssertEqual(tables.count, 1)
        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    // MARK: - テーブル更新

    func test_テーブル更新_名前と会場レイアウトが反映され列数はクランプされる() {
        let interactor = makeInteractor(names: ["A", "B"])
        let tableID = interactor.currentTables()[0].id

        let tables = interactor.updateTable(
            tableUpdate(id: tableID, name: "幹事席", capacity: 2, columnCount: 9, layoutDirection: .top, layoutText: "ステージ側")
        )

        XCTAssertEqual(tables[0].name, "幹事席")
        XCTAssertEqual(tables[0].capacity, 2)
        XCTAssertEqual(tables[0].columnCount, 2)
        XCTAssertEqual(tables[0].layoutDirection, .top)
        XCTAssertEqual(tables[0].layoutText, "ステージ側")
    }

    func test_テーブル更新_定員変更で不要になった空テーブルは末尾から削除される() {
        let attendees = makeAttendees(["A", "B", "C"])
        let interactor = SeatingChartInteractor(attendees: attendees)
        _ = interactor.addTable()
        _ = interactor.addTable()
        XCTAssertEqual(interactor.currentTables().count, 3)

        let tables = interactor.updateTable(
            tableUpdate(id: interactor.currentTables()[0].id, name: "テーブルA", capacity: 3, columnCount: 2)
        )

        XCTAssertEqual(tables.count, 1)
        XCTAssertEqual(tables[0].capacity, 3)
        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    func test_テーブル更新_定員が変わらない場合はテーブル構成が維持される() {
        let interactor = makeInteractor(names: ["A", "B", "C"])
        _ = interactor.addTable()
        XCTAssertEqual(interactor.currentTables().count, 2)

        let tables = interactor.updateTable(
            tableUpdate(
                id: interactor.currentTables()[0].id,
                name: "改名のみ",
                capacity: interactor.currentTables()[0].capacity,
                columnCount: 2
            )
        )

        XCTAssertEqual(tables.count, 2)
        XCTAssertEqual(tables[0].name, "改名のみ")
    }

    // MARK: - 一括適用

    func test_一括適用_全テーブルの定員と列数が統一され不足分が追加される() {
        let attendees = makeAttendees(["A", "B", "C", "D", "E"])
        let interactor = SeatingChartInteractor(attendees: attendees)

        let tables = interactor.updateAllTables(
            tableUpdate(
                id: interactor.currentTables()[0].id,
                name: "幹事席",
                capacity: 2,
                columnCount: 5,
                layoutDirection: .top,
                layoutText: "ステージ側",
                applyToAll: true
            )
        )

        XCTAssertEqual(tables.count, 3)
        XCTAssertTrue(tables.allSatisfy { $0.capacity == 2 && $0.columnCount == 2 })
        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    func test_一括適用_名前と会場レイアウトは編集中のテーブルにだけ反映される() {
        let interactor = makeInteractor(names: ["A", "B", "C", "D", "E"])

        let tables = interactor.updateAllTables(
            tableUpdate(
                id: interactor.currentTables()[0].id,
                name: "幹事席",
                capacity: 4,
                columnCount: 2,
                layoutDirection: .top,
                layoutText: "ステージ側",
                applyToAll: true
            )
        )

        XCTAssertEqual(tables[0].name, "幹事席")
        XCTAssertEqual(tables[0].layoutDirection, .top)
        XCTAssertEqual(tables[0].layoutText, "ステージ側")
        XCTAssertEqual(tables[1].layoutDirection, .none)
        XCTAssertEqual(tables[1].layoutText, "")
    }

    func test_一括適用で改名すると空いた名前が追加テーブルに再利用される_既知の課題() {
        let interactor = makeInteractor(names: ["A", "B", "C", "D", "E"])

        let tables = interactor.updateAllTables(
            tableUpdate(
                id: interactor.currentTables()[0].id,
                name: "幹事席",
                capacity: 2,
                columnCount: 2,
                applyToAll: true
            )
        )

        XCTAssertEqual(tables.map(\.name), ["幹事席", "テーブルB", "テーブルA"])
    }

    func test_一括適用後に追加するテーブルは同じ定員と列数を引き継ぐ() {
        let interactor = makeInteractor(names: ["A", "B"])

        _ = interactor.updateAllTables(
            tableUpdate(
                id: interactor.currentTables()[0].id,
                name: "卓",
                capacity: 6,
                columnCount: 3,
                applyToAll: true
            )
        )
        let tables = interactor.addTable()

        XCTAssertEqual(tables.last?.capacity, 6)
        XCTAssertEqual(tables.last?.columnCount, 3)
    }

    // MARK: - ロック

    func test_ロック切替は指定した座席にだけ作用する() {
        let interactor = makeInteractor(names: ["A", "B"])
        let tableID = interactor.currentTables()[0].id
        let memberID = interactor.currentTables()[0].assignedMembers[0].id

        XCTAssertFalse(interactor.currentTables()[0].assignedMembers[0].isLocked)

        _ = interactor.toggleLock(tableID: tableID, memberID: memberID)
        XCTAssertTrue(interactor.currentTables()[0].assignedMembers[0].isLocked)
        XCTAssertFalse(interactor.currentTables()[0].assignedMembers[1].isLocked)

        _ = interactor.toggleLock(tableID: tableID, memberID: memberID)
        XCTAssertFalse(interactor.currentTables()[0].assignedMembers[0].isLocked)
    }

    // MARK: - シャッフル（状態保持）

    func test_シャッフルしても全参加者が保持される() {
        let attendees = makeAttendees((1...12).map { "参加者\($0)" })
        let interactor = SeatingChartInteractor(attendees: attendees)

        let tables = interactor.shuffleSeats()

        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    // MARK: - テンプレート適用

    func test_テンプレート適用_レイアウトが復元され会場列数がVenueSettingsへ入る() {
        let attendees = makeAttendees(["A", "B", "C", "D", "E", "F"])
        let interactor = SeatingChartInteractor(attendees: attendees)
        let snapshot = LayoutTemplateSnapshot(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        let tables = interactor.applyTemplate(snapshot)

        XCTAssertEqual(interactor.currentVenueSettings().globalColumnCount, 4)
        XCTAssertEqual(tables.map(\.name), ["受付卓", "奥卓"])
        XCTAssertTrue(tables.allSatisfy { $0.capacity == 3 && $0.columnCount == 3 })
        XCTAssertEqual(tables[0].layoutDirection, .left)
        XCTAssertEqual(tables[1].layoutText, "窓際")
        XCTAssertEqual(assignedIDs(tables), Set(attendees.map(\.id)))
    }

    func test_テンプレート適用_全テーブルが同一構成なら以降の既定値も揃う() {
        let interactor = makeInteractor(names: ["A"])
        let snapshot = LayoutTemplateSnapshot(
            name: "均一レイアウト",
            tables: [TableTemplate(name: "卓1", capacity: 5, columnCount: 5, layoutDirection: .none, layoutText: "")],
            globalColumnCount: 2
        )

        _ = interactor.applyTemplate(snapshot)
        let tables = interactor.addTable()

        XCTAssertEqual(tables.last?.capacity, 5)
        XCTAssertEqual(tables.last?.columnCount, 5)
    }

    func test_テンプレート適用_同一インデックスのテーブルIDを引き継ぐ() {
        let interactor = makeInteractor(names: ["A", "B", "C", "D", "E", "F"])
        let originalIDs = interactor.currentTables().map(\.id)
        let snapshot = LayoutTemplateSnapshot(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        let tables = interactor.applyTemplate(snapshot)

        XCTAssertEqual(tables.map(\.id), originalIDs)
    }

    // MARK: - テンプレート保存スナップショット

    func test_テンプレート保存_現在のレイアウトと会場列数がスナップショットされる() throws {
        let interactor = makeInteractor(names: ["A", "B", "C", "D", "E"])
        interactor.grantSessionUnlock()
        _ = try interactor.applyColumnCount(3)

        let snapshot = interactor.makeLayoutTemplate(named: "歓迎会")

        XCTAssertEqual(snapshot?.name, "歓迎会")
        XCTAssertEqual(snapshot?.globalColumnCount, 3)
        XCTAssertEqual(snapshot?.tables.count, 2)
        XCTAssertEqual(snapshot?.tables.map(\.capacity), [4, 4])
        XCTAssertEqual(snapshot?.tables.map(\.name), ["テーブルA", "テーブルB"])
    }

    func test_テンプレート保存_名前が空白のみならスナップショットされない() {
        let interactor = makeInteractor(names: ["A"])

        XCTAssertNil(interactor.makeLayoutTemplate(named: "   "))
    }

    func test_テンプレート保存可否_無料枠は3件まで() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let interactor = makeInteractor(names: ["A"], templateGateway: gateway)

        XCTAssertEqual(interactor.templateSaveAvailability(), .available)

        try interactor.saveCurrentLayoutAsTemplate(named: "1")
        try interactor.saveCurrentLayoutAsTemplate(named: "2")
        try interactor.saveCurrentLayoutAsTemplate(named: "3")

        XCTAssertEqual(
            interactor.templateSaveAvailability(),
            .limitReached(currentCount: 3, limit: FeatureLimit.freeTemplateCount)
        )
        XCTAssertThrowsError(try interactor.saveCurrentLayoutAsTemplate(named: "4")) { error in
            XCTAssertEqual(
                error as? TemplateSaveError,
                .limitReached(currentCount: 3, limit: FeatureLimit.freeTemplateCount)
            )
        }
    }

    // MARK: - 会場設定とセッション解放

    func test_列数2以下は広告不要ですぐ適用できる() throws {
        let interactor = makeInteractor(names: ["A"])

        XCTAssertEqual(interactor.columnCountChangeRequirement(for: 2), .none)
        let settings = try interactor.applyColumnCount(1)
        XCTAssertEqual(settings.globalColumnCount, 1)
    }

    func test_列数3以上は未解放なら広告が必要() {
        let interactor = makeInteractor(names: ["A"])

        XCTAssertEqual(interactor.columnCountChangeRequirement(for: 3), .rewardedAd)
        XCTAssertThrowsError(try interactor.applyColumnCount(4)) { error in
            XCTAssertEqual(error as? VenueSettingsError, .unlockRequired(requested: 4))
        }
        XCTAssertEqual(interactor.currentVenueSettings().globalColumnCount, 2)
    }

    func test_セッション解放後は3列以上も適用でき画面を跨いでも維持される() throws {
        let gateway = FeatureUnlockState()
        let first = makeInteractor(names: ["A"], featureUnlock: gateway)
        first.grantSessionUnlock()
        _ = try first.applyColumnCount(5)
        XCTAssertEqual(first.currentVenueSettings().globalColumnCount, 5)

        let second = makeInteractor(names: ["B"], featureUnlock: gateway)
        XCTAssertTrue(second.isSessionUnlocked)
        XCTAssertEqual(second.columnCountChangeRequirement(for: 8), .none)
        _ = try second.applyColumnCount(8)
        XCTAssertEqual(second.currentVenueSettings().globalColumnCount, 8)
    }

    // MARK: - 共有テキスト

    func test_共有テキストはテーブル名と配置を含む() {
        let interactor = makeInteractor(names: ["A", "B"])
        let text = interactor.makeShareText()

        XCTAssertTrue(text.contains("【サクッと席決め】"))
        XCTAssertTrue(text.contains("テーブルA"))
        XCTAssertTrue(text.contains("A"))
        XCTAssertTrue(text.contains("#サクッと席決め"))
    }

    func test_画像共有は常にリワード広告が必要() {
        let interactor = makeInteractor(names: ["A"])
        XCTAssertEqual(interactor.shareImageRequirement(), .rewardedAd)
    }
}
