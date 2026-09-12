//
//  SeatingChartPresenterTests.swift
//  SakuttoSeatTests
//
//  refactor_seating.md Phase 4（Gateway / Router 仲介の回帰）
//  refactor_templateListView.md Phase 0 / Phase 2 / Phase 3（TemplateList Output は ID。cancel は閉じるから接続）
//  refactor_templateListView.md Phase 4（シート期間中の子 Presenter identity）
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
        try gateway.insert(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側"),
                TableTemplate(name: "奥卓", capacity: 3, columnCount: 3, layoutDirection: .right, layoutText: "窓際")
            ],
            globalColumnCount: 4
        )
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)
        presenter.didTapLoadTemplate()

        presenter.templateListDidSelect(id: id)

        XCTAssertEqual(presenter.globalColumnCount, 4)
        XCTAssertEqual(presenter.viewData.globalColumnCount, 4)
        XCTAssertNil(presenter.route)
        XCTAssertNil(presenter.templateListPresenter)
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
        XCTAssertEqual(try gateway.fetchSummaries().count, 3)

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

        let summaries = try gateway.fetchSummaries()
        XCTAssertEqual(summaries.count, 1)
        let saved = try XCTUnwrap(gateway.fetch(id: try XCTUnwrap(summaries.first?.id)))
        XCTAssertEqual(saved.name, "歓迎会")
        XCTAssertEqual(saved.globalColumnCount, 3)
        XCTAssertEqual(saved.tables.map(\.name), ["テーブルA", "テーブルB"])
        XCTAssertEqual(saved.tables.map(\.capacity), [4, 4])
    }

    func test_テンプレート保存_名前が空白のみなら保存されない() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A"], templateGateway: gateway)

        presenter.didConfirmSaveTemplate(name: "   ")

        XCTAssertTrue(try gateway.fetchSummaries().isEmpty)
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
        XCTAssertNotNil(presenter.templateListPresenter)
    }

    func test_TemplateListOutputの選択は会場列数を反映してシートを閉じる() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let presenter = makePresenter(names: ["A", "B", "C", "D", "E", "F"], templateGateway: gateway)
        presenter.didTapLoadTemplate()
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
        XCTAssertNil(presenter.templateListPresenter)
        guard case .scrollToTop = presenter.canvasEvent else {
            return XCTFail("テンプレート適用後は先頭へスクロールする")
        }
    }

    func test_TemplateListOutputのキャンセルはシートを閉じる() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()

        presenter.templateListDidCancel()

        XCTAssertNil(presenter.route)
        XCTAssertNil(presenter.templateListPresenter)
    }

    func test_存在しないIDの選択はシートを閉じない() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()
        let child = presenter.templateListPresenter

        presenter.templateListDidSelect(id: UUID())

        XCTAssertEqual(presenter.route, .templateList)
        XCTAssertTrue(presenter.templateListPresenter === child)
    }

    func test_テンプレートシートは親と同じGatewayインスタンスで組み立てる() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(name: "共有", tables: [], globalColumnCount: 2)
        let presenter = makePresenter(names: ["A"], templateGateway: gateway)
        let fetchCountBeforeSheet = gateway.fetchSummariesCallCount

        presenter.didTapLoadTemplate()
        _ = presenter.makeRouteSheet(.templateList)

        XCTAssertEqual(presenter.route, .templateList)
        XCTAssertGreaterThan(gateway.fetchSummariesCallCount, fetchCountBeforeSheet)
    }

    // MARK: - シート identity（Phase 4）

    func test_テンプレートシート期間中は同一の子Presenterを返す() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()
        let first = presenter.templateListPresenter
        XCTAssertNotNil(first)

        _ = presenter.makeRouteSheet(.templateList)
        XCTAssertTrue(presenter.templateListPresenter === first)
        _ = presenter.makeRouteSheet(.templateList)
        XCTAssertTrue(presenter.templateListPresenter === first)
    }

    func test_テンプレートシートを閉じたら子Presenterを破棄し再表示で新規assembleする() {
        let presenter = makePresenter(names: ["A"])
        presenter.didTapLoadTemplate()
        let first = presenter.templateListPresenter
        XCTAssertNotNil(first)

        presenter.dismissRoute()
        XCTAssertNil(presenter.templateListPresenter)

        presenter.didTapLoadTemplate()
        let second = presenter.templateListPresenter
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
    }

    func test_シート再組み立てでも子のrouteが消えない() throws {
        let presenter = makePresenter(names: ["A"], templateGateway: FailingFetchSeatingTemplateGateway())
        presenter.didTapLoadTemplate()
        let child = try XCTUnwrap(presenter.templateListPresenter)
        XCTAssertEqual(
            child.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )

        _ = presenter.makeRouteSheet(.templateList)
        _ = presenter.makeRouteSheet(.templateList)

        XCTAssertTrue(presenter.templateListPresenter === child)
        XCTAssertEqual(
            child.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )
    }

    func test_テンプレートシートを閉じたあとGateway差し替えで新しい子が読む() throws {
        let firstGateway = InMemorySeatingTemplateGateway()
        try firstGateway.insert(name: "最初", tables: [], globalColumnCount: 2)
        let interactor = SeatingChartInteractor(
            attendees: [Attendee(name: "A")],
            templateGateway: firstGateway
        )
        let presenter = SeatingChartPresenter(interactor: interactor, router: SeatingChartRouter())
        presenter.didTapLoadTemplate()
        XCTAssertEqual(presenter.templateListPresenter?.viewData.rows.map(\.name), ["最初"])
        presenter.dismissRoute()

        let secondGateway = InMemorySeatingTemplateGateway()
        try secondGateway.insert(name: "差し替え後", tables: [], globalColumnCount: 2)
        interactor.attachTemplateGateway(secondGateway)
        presenter.didTapLoadTemplate()

        XCTAssertEqual(presenter.templateListPresenter?.viewData.rows.map(\.name), ["差し替え後"])
    }
}

/// fetchSummaries だけ失敗させるテスト用 Gateway（子の loadFailed route を残す）
private final class FailingFetchSeatingTemplateGateway: SeatingTemplateGatewayBase {
    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        throw NSError(
            domain: "SeatingChartPresenterTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }
}

/// 親シート組み立てが同じ Gateway インスタンスを子へ渡すことを数える
private final class FetchCountingSeatingTemplateGateway: SeatingTemplateGatewayBase {
    private let inner = InMemorySeatingTemplateGateway()
    private(set) var fetchSummariesCallCount = 0

    override func fetchCount() throws -> Int {
        try inner.fetchCount()
    }

    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        fetchSummariesCallCount += 1
        return try inner.fetchSummaries()
    }

    override func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot? {
        try inner.fetch(id: id)
    }

    override func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws {
        try inner.insert(name: name, tables: tables, globalColumnCount: globalColumnCount)
    }

    override func delete(ids: [SeatingTemplateID]) throws {
        try inner.delete(ids: ids)
    }
}
