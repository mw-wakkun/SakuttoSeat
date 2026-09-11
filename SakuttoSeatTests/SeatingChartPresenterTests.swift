//
//  SeatingChartPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 4（Gateway / Router 仲介の回帰）
//  refactor_templateListView.md Phase 0 / Phase 2（TemplateList Output は ID。cancel は閉じるから接続）
//

import XCTest
@testable import SakuttoSeat

/// ドメイン判断は Interactor 側で固定する。ここでは ViewData / route / Gateway 仲介だけを検証する。
@MainActor
final class SeatingChartPresenterTests: XCTestCase {

    private func makePresenter(
        names: [String],
        featureUnlock: FeatureUnlockState? = nil,
        templateGateway: SeatingTemplateGatewayBase = InMemorySeatingTemplateGateway()
    ) -> SeatingChartPresenter {
        let interactor = SeatingChartInteractor(
            attendees: names.map { Attendee(name: $0) },
            featureUnlock: featureUnlock,
            templateGateway: templateGateway
        )
        return SeatingChartPresenter(interactor: interactor, router: SeatingChartRouter())
    }

    private func firstTableID(in presenter: SeatingChartPresenter) -> TableID {
        for row in presenter.viewData.rows {
            for item in row.items {
                if case .table(let table) = item {
                    return table.id
                }
            }
        }
        XCTFail("テーブルが1つもない")
        return UUID()
    }

    func test_テーブル編集の確定でViewDataが更新され先頭へスクロールする() {
        let presenter = makePresenter(names: ["A", "B"])
        let tableID = firstTableID(in: presenter)

        presenter.didCommitTableEdit(
            TableUpdateRequest(
                tableID: tableID,
                name: "幹事席",
                capacity: 2,
                columnCount: 2,
                layoutDirection: .top,
                layoutText: "ステージ側",
                applyToAll: false
            )
        )

        if case .table(let table) = presenter.viewData.rows[0].items[0] {
            XCTAssertEqual(table.name, "幹事席")
            XCTAssertEqual(table.badge, .top)
        } else {
            XCTFail("先頭はテーブルであるべき")
        }
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("編集確定後は先頭へスクロールする")
        }
    }

    func test_テンプレート適用で会場列数がViewDataに反映され先頭へスクロールする() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"], templateGateway: gateway)
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )
        try gateway.insert(template)
        presenter.didTapLoadTemplate()

        presenter.templateListDidSelect(id: template.id)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("テンプレート適用後は先頭へスクロールする")
        }
    }

    func test_テンプレート保存_無料枠は3件までで4件目から上限アラートになる() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B"], templateGateway: gateway)

        presenter.didTapSaveTemplate()
        XCTAssertEqual(presenter.route, .saveTemplatePrompt)

        presenter.didConfirmSaveTemplate(name: "1件目")
        presenter.didConfirmSaveTemplate(name: "2件目")
        presenter.didConfirmSaveTemplate(name: "3件目")
        XCTAssertEqual(gateway.templates.count, 3)

        presenter.didTapSaveTemplate()
        XCTAssertEqual(
            presenter.route,
            .alert(.templateLimitReached(currentCount: 3, limit: FeatureLimit.freeTemplateCount))
        )
    }

    func test_テンプレート保存_現在のレイアウトと会場列数が保存される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"], templateGateway: gateway)
        presenter.sessionUnlockedColumns = true
        presenter.globalColumnCount = 3

        presenter.didConfirmSaveTemplate(name: "歓迎会")

        XCTAssertEqual(gateway.templates.count, 1)
        XCTAssertEqual(gateway.templates[0].name, "歓迎会")
        XCTAssertEqual(gateway.templates[0].globalColumnCount, 3)
        XCTAssertEqual(gateway.templates[0].tables.map(\.name), ["テーブルA", "テーブルB"])
        XCTAssertEqual(gateway.templates[0].tables.map(\.capacity), [4, 4])
    }

    func test_テンプレート保存_名前が空白のみなら保存されない() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A"], templateGateway: gateway)

        presenter.didConfirmSaveTemplate(name: "   ")

        XCTAssertTrue(gateway.templates.isEmpty)
    }

    func test_セッション解放フラグはGatewayへ委譲される() {
        let gateway = FeatureUnlockState()
        let presenter = makePresenter(names: ["A"], featureUnlock: gateway)

        XCTAssertFalse(presenter.sessionUnlockedColumns)
        presenter.sessionUnlockedColumns = true
        XCTAssertTrue(presenter.sessionUnlockedColumns)
        XCTAssertTrue(gateway.isSessionUnlocked)
    }

    func test_共有はShareモジュールへ委譲され選択シートが開く() {
        let presenter = makePresenter(names: ["太郎"])

        presenter.didTapShare()

        XCTAssertEqual(presenter.share.route, .selection)
        XCTAssertNil(presenter.route, "共有は親の route を使わない")
    }

    func test_会場設定の適用結果がOutput経由で会場列数に反映される() {
        let presenter = makePresenter(names: ["A"])
        presenter.route = .venueSettings
        presenter.sessionUnlockedColumns = true

        presenter.venueSettingsDidApply(columnCount: 4)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
    }

    func test_テーブル編集のOutputで確定するとシートが閉じる() {
        let presenter = makePresenter(names: ["A", "B"])
        let tableID = firstTableID(in: presenter)
        presenter.route = .tableEdit(tableID)

        presenter.tableEditDidCommit(
            TableUpdateRequest(
                tableID: tableID,
                name: "幹事席",
                capacity: 4,
                columnCount: 2,
                layoutDirection: .none,
                layoutText: "",
                applyToAll: false
            )
        )

        XCTAssertNil(presenter.route)
        if case .table(let table) = presenter.viewData.rows[0].items[0] {
            XCTAssertEqual(table.name, "幹事席")
        } else {
            XCTFail("先頭はテーブルであるべき")
        }
    }

    func test_テーブル編集のOutputで削除するとテーブルが減る() {
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E"])
        let tableID = firstTableID(in: presenter)
        presenter.route = .tableEdit(tableID)

        presenter.tableEditDidRequestDelete(tableID: tableID)

        XCTAssertNil(presenter.route)
        let remainingIDs = presenter.viewData.rows
            .flatMap(\.items)
            .compactMap { item -> TableID? in
                if case .table(let table) = item { return table.id }
                return nil
            }
        XCTAssertFalse(remainingIDs.contains(tableID))
    }

    func test_didTapLoadTemplateはテンプレート一覧シートを開く() {
        let presenter = makePresenter(names: ["A"])

        presenter.didTapLoadTemplate()

        XCTAssertEqual(presenter.route, .templateList)
    }

    func test_TemplateListOutputの選択は会場列数を反映してシートを閉じる() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"], templateGateway: gateway)
        presenter.didTapLoadTemplate()
        let template = SeatingLayoutTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )
        try gateway.insert(template)

        presenter.templateListDidSelect(id: template.id)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("テンプレート適用後は先頭へスクロールする")
        }
    }

    func test_TemplateListOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()

        presenter.templateListDidCancel()

        XCTAssertNil(presenter.route)
    }

    func test_存在しないIDの選択はシートを閉じない() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()

        presenter.templateListDidSelect(id: UUID())

        XCTAssertEqual(presenter.route, .templateList)
    }

    func test_makeRouteSheetはテンプレート一覧を組み立てる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()

        _ = presenter.makeRouteSheet(.templateList)
    }
}
