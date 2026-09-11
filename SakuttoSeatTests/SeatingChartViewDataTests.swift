//
//  SeatingChartViewDataTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 2 / 3（ViewData / Route の回帰）
//  refactor_templateListView.md Phase 3（テンプレート適用は ID。Gateway は Snapshot insert）
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
        let id = try XCTUnwrap(gateway.fetchAll().first?.id)

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
        let id = try XCTUnwrap(gateway.fetchAll().first?.id)

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
}
