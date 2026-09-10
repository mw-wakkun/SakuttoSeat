//
//  SeatingChartViewDataTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 2 / 3（ViewData / Route の回帰）
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartViewDataTests: XCTestCase {

    private func makePresenter(names: [String]) -> SeatingChartPresenter {
        SeatingChartPresenter(
            interactor: SeatingChartInteractor(attendees: names.map { Attendee(name: $0) }),
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

    func test_テンプレート適用_同一インデックスのテーブルIDを引き継ぐ() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"])
        let originalIDs = tableIDs(in: presenter.viewData)
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        presenter.applyTemplate(template)

        XCTAssertEqual(tableIDs(in: presenter.viewData), originalIDs)
    }

    func test_didSelectTemplate_会場列数もViewDataに反映される() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"])
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )

        presenter.didSelectTemplate(template)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
    }

    func test_didTapSaveTemplate_保存不可ならunlockルートになる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapSaveTemplate(canSave: false)
        XCTAssertEqual(presenter.route, .unlockForSave)

        presenter.didTapSaveTemplate(canSave: true)
        XCTAssertEqual(presenter.route, .saveTemplatePrompt)
    }
}
