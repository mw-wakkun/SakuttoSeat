//
//  SeatingChartViewDataTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 2 / 3（ViewData / Route の回帰）
//  refactor_templateListView.md Phase 3（テンプレート適用は ID。Gateway は Snapshot insert）
//  v2.1 Phase 2（Snapshot 高画質のフィラー省略）
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartViewDataTests: XCTestCase {

    private func makePresenter(names: [String], templateGateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway()) -> SeatingChartPresenter {
        SeatingChartPresenter(
            interactor: SeatingChartInteractor(
                attendees: names.map { Attendee(name: $0) },
                templateGateway: templateGateway
            ),
            router: SeatingChartRouter()
        )
    }

    private func tableIDs(in viewData: SeatingChartViewData) -> [TableID] {
        viewData.rows.flatMap(\.items).compactMap { item in
            if case .table(let table) = item { return table.id }
            return nil
        }
    }

    private func firstTable(in viewData: SeatingChartViewData) -> TableViewData? {
        for row in viewData.rows {
            for item in row.items {
                if case .table(let table) = item {
                    return table
                }
            }
        }
        return nil
    }

    func test_ViewData_行分割は会場列数に従い末尾に追加ボタンを含む() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"])
        presenter.globalColumnCount = 2

        XCTAssertEqual(presenter.viewData.rows.count, 2)
        XCTAssertEqual(presenter.viewData.rows[0].items.count, 2)
        XCTAssertEqual(presenter.viewData.rows[1].items.count, 1)
        XCTAssertEqual(presenter.viewData.rows[1].trailingFillerCount, 1)

        if case .addButton = presenter.viewData.rows[1].items[0] {
            // ok
        } else {
            XCTFail("末尾行の末尾は追加ボタンであるべき")
        }
    }

    func test_ViewData_行idは先頭アイテムの安定idでありindexではない() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"])
        presenter.globalColumnCount = 2

        let firstTableID = tableIDs(in: presenter.viewData)[0].uuidString
        XCTAssertEqual(presenter.viewData.rows[0].id, firstTableID)
    }

    func test_ViewData_座席は空席パディング込みで定員数になる() {
        let presenter = makePresenter(names: ["A"])
        let tableData = firstTable(in: presenter.viewData)

        XCTAssertEqual(tableData?.seats.count, 4)
        XCTAssertEqual(tableData?.seats.filter(\.isEmpty).count, 3)
        XCTAssertEqual(tableData?.needsHorizontalScroll, false)
    }

    func test_accessibilitySummaryは氏名を並べず着席数と定員() {
        let presenter = makePresenter(names: ["太郎", "花子"])
        let summary = firstTable(in: presenter.viewData)?.accessibilitySummary

        XCTAssertEqual(summary, "テーブルA、2人着席、定員4")
        XCTAssertFalse(summary?.contains("太郎") ?? true)
        XCTAssertFalse(summary?.contains("花子") ?? true)
    }

    func test_ViewData_列数が5以上なら横スクロールが必要() {
        let presenter = makePresenter(names: ["A"])
        let tableID = tableIDs(in: presenter.viewData)[0]

        presenter.didCommitTableEdit(
            TableUpdateRequest(
                tableID: tableID,
                name: "卓",
                capacity: 6,
                columnCount: 5,
                layoutDirection: .none,
                layoutText: "",
                applyToAll: false
            )
        )

        let tableData = firstTable(in: presenter.viewData)
        XCTAssertEqual(tableData?.columnCount, 5)
        XCTAssertEqual(tableData?.needsHorizontalScroll, true)
    }

    func test_route_テーブルタップでtableEditになりindexではなくIDを使う() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"])
        let tableID = tableIDs(in: presenter.viewData)[1]

        presenter.didTapTable(id: tableID)

        XCTAssertEqual(presenter.route, .tableEdit(tableID))
    }

    func test_テンプレート適用_同一インデックスのテーブルIDを引き継ぐ() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"], templateGateway: gateway)
        let originalIDs = tableIDs(in: presenter.viewData)
        try gateway.insert(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.templateListDidSelect(id: id)

        XCTAssertEqual(tableIDs(in: presenter.viewData), originalIDs)
    }

    func test_didSelectTemplate_会場列数もViewDataに反映される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"], templateGateway: gateway)
        try gateway.insert(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.templateListDidSelect(id: id)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
    }

    func test_didTapSaveTemplate_上限到達ならテンプレート上限アラートになる() throws {
        let gateway = InMemorySeatingTemplateGateway()
        for index in 1...FeatureLimit.freeTemplateCount {
            try gateway.insert(name: "既存\(index)", tables: [], globalColumnCount: 2)
        }
        let presenter = SeatingChartPresenter(
            interactor: SeatingChartInteractor(
                attendees: [Attendee(name: "A")],
                templateGateway: gateway
            ),
            router: SeatingChartRouter()
        )

        presenter.didTapSaveTemplate()
        XCTAssertEqual(
            presenter.route,
            .alert(.templateLimitReached(
                currentCount: FeatureLimit.freeTemplateCount,
                limit: FeatureLimit.freeTemplateCount
            ))
        )

        let availablePresenter = makePresenter(names: ["A"])
        availablePresenter.didTapSaveTemplate()
        XCTAssertEqual(availablePresenter.route, .saveTemplatePrompt)
    }

    func test_tableOnlyRows_標準は会場列に合わせてフィラーを残す() {
        let interactor = SeatingChartInteractor(attendees: [Attendee(name: "A")])
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        let rows = SeatingChartViewDataBuilder.tableOnlyRows(from: viewData)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].items.count, 1)
        XCTAssertEqual(rows[0].trailingFillerCount, 1)
    }

    func test_tableOnlyRows_高画質はフィラーを切る() {
        let interactor = SeatingChartInteractor(attendees: [Attendee(name: "A")])
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        let rows = SeatingChartViewDataBuilder.tableOnlyRows(from: viewData, hidesFillers: true)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].items.count, 1)
        XCTAssertEqual(rows[0].trailingFillerCount, 0)
    }

    func test_SnapshotView_標準と高画質で余白と列数が分かれる() {
        let interactor = SeatingChartInteractor(attendees: [Attendee(name: "A")])
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        let standard = SeatingChartSnapshotView(viewData: viewData)
        let highRes = SeatingChartSnapshotView(viewData: viewData, layout: .highRes)

        XCTAssertEqual(standard.layout, .standard)
        XCTAssertFalse(standard.layout.hidesFillers)
        XCTAssertEqual(standard.layout.contentPadding, 32)
        XCTAssertEqual(SeatingChartSnapshotView.exportColumnCount(for: viewData), 2)
        XCTAssertEqual(
            SeatingChartSnapshotView.intrinsicWidth(columnCount: 2),
            140 * 2 + 16 + 32 * 2
        )

        XCTAssertEqual(highRes.layout, .highRes)
        XCTAssertTrue(highRes.layout.hidesFillers)
        XCTAssertEqual(highRes.layout.contentPadding, 8)
        XCTAssertEqual(SeatingChartSnapshotView.exportColumnCount(for: viewData, layout: .highRes), 1)
        XCTAssertEqual(
            SeatingChartSnapshotView.intrinsicWidth(columnCount: 1, layout: .highRes),
            140 + 8 * 2
        )
        XCTAssertLessThan(
            SeatingChartSnapshotView.intrinsicWidth(
                columnCount: SeatingChartSnapshotView.exportColumnCount(for: viewData, layout: .highRes),
                layout: .highRes
            ),
            SeatingChartSnapshotView.intrinsicWidth(columnCount: 2)
        )
    }

    func test_exportColumnCount_テーブルが会場列以上なら高画質も会場列幅() {
        let interactor = SeatingChartInteractor(attendees: [Attendee(name: "A")])
        _ = interactor.addTable()
        _ = interactor.addTable()
        let viewData = SeatingChartViewDataBuilder.build(
            tables: interactor.currentTables(),
            globalColumnCount: 2
        )

        XCTAssertEqual(interactor.currentTables().count, 3)
        XCTAssertEqual(SeatingChartSnapshotView.exportColumnCount(for: viewData), 2)
        XCTAssertEqual(SeatingChartSnapshotView.exportColumnCount(for: viewData, layout: .highRes), 2)

        let rows = SeatingChartViewDataBuilder.tableOnlyRows(from: viewData, hidesFillers: true)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].items.count, 2)
        XCTAssertEqual(rows[0].trailingFillerCount, 0)
        XCTAssertEqual(rows[1].items.count, 1)
        XCTAssertEqual(rows[1].trailingFillerCount, 0)
    }
}

final class SeatingChartCopyTests: XCTestCase {
    func test_卓追加と下段Hint() {
        XCTAssertEqual(SeatingChartCopy.addTableTitle, "テーブル追加")
        XCTAssertEqual(SeatingChartCopy.addTableAccessibilityLabel, "テーブルを追加")
        XCTAssertEqual(SeatingChartCopy.addTableUnlockHint, "動画を見るとテーブルを増やせます")
        XCTAssertEqual(SeatingChartCopy.loadTemplateHint, "保存済みレイアウトの一覧を開きます")
        XCTAssertEqual(SeatingChartCopy.saveHint, "現在のレイアウトをテンプレートとして保存します")
        XCTAssertEqual(SeatingChartCopy.shareHint, "座席表を共有します")
        XCTAssertEqual(SeatingChartCopy.shuffleHint, "席順をシャッフルします")
        XCTAssertEqual(SeatingChartCopy.loadTemplateTitle, "テンプレート")
        XCTAssertEqual(SeatingChartCopy.editTableHint, "ダブルタップでテーブルを編集します")
        XCTAssertEqual(SeatingChartCopy.lockedValue, "ロック中")
        XCTAssertEqual(SeatingChartCopy.lockSeatHint, "ダブルタップでロックします")
        XCTAssertEqual(SeatingChartCopy.unlockSeatHint, "ダブルタップでロックを解除します")
    }
}
