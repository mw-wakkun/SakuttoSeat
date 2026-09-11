//
//  SeatingTemplateTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0（Gateway の characterization）
//  refactor_templateListView.md Phase 2（子 VIPER の一覧・削除・Output・取得失敗）
//  refactor_templateListView.md Phase 3（Snapshot 戻り / delete(ids:) / insert(fields)）
//  fetchSummaries / fetch(id:)。fetchAll は削除。
//  refactor_templateListView.md Phase 5（ViewData は件数ラベルのみ。空 / 1 / 3 件の部品呼び出し）
//  refactor_templateListView.md Phase 6（閉じる / 編集 / 空状態 / 行の A11y Copy）
//

import SwiftData
import SwiftUI
import XCTest
@testable import SakuttoSeat

// MARK: - Gateway（In-Memory）

final class SeatingTemplateGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["新しい", "古い"])
    }

    func test_insert後に件数が増える() throws {
        let gateway = InMemorySeatingTemplateGateway()
        XCTAssertEqual(try gateway.fetchCount(), 0)

        try gateway.insert(name: "1件目", tables: [], globalColumnCount: 2)

        XCTAssertEqual(try gateway.fetchCount(), 1)
        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["1件目"])
    }

    func test_ID指定で削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let newerID = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        try gateway.delete(ids: [newerID])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["古い"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_複数IDで削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "真ん中", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let templates = try gateway.fetchSummaries()

        try gateway.delete(ids: [templates[0].id, templates[2].id])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["真ん中"])
    }

    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        try gateway.delete(ids: [UUID()])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["残る"])
    }

    func test_空のID配列の削除は何もしない() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        try gateway.delete(ids: [])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["残る"])
    }

    func test_ID指定で1件取得する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側")
            ],
            globalColumnCount: 2
        )

        let inserted = try XCTUnwrap(gateway.fetchSummaries().first)
        let fetched = try XCTUnwrap(gateway.fetch(id: inserted.id))

        XCTAssertEqual(fetched.id, inserted.id)
        XCTAssertEqual(fetched.name, "宴会場")
        XCTAssertEqual(fetched.tables.map(\.name), ["受付卓"])
        XCTAssertEqual(fetched.globalColumnCount, 2)
    }

    func test_存在しないIDの取得はnil() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        XCTAssertNil(try gateway.fetch(id: UUID()))
        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["残る"])
    }

    func test_一覧のtableCountLabelは件数ラベルである() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "空", tables: [], globalColumnCount: 2)
        try gateway.insert(
            name: "1卓",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
            ],
            globalColumnCount: 2
        )
        try gateway.insert(
            name: "複数",
            tables: [
                TableTemplate(name: "前列", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: ""),
                TableTemplate(name: "後列", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
            ],
            globalColumnCount: 2
        )

        let summaries = try gateway.fetchSummaries()
        XCTAssertEqual(summaries.map(\.name), ["複数", "1卓", "空"])
        XCTAssertEqual(
            summaries.map(\.tableCountLabel),
            ["テーブル数: 2", "テーブル数: 1", "テーブル数: 0"]
        )

        let manyID = try XCTUnwrap(summaries.first?.id)
        XCTAssertEqual(try gateway.fetch(id: manyID)?.tables.map(\.name), ["前列", "後列"])
    }
}

// MARK: - Gateway（SwiftData In-Memory）

@MainActor
final class SwiftDataSeatingTemplateGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["新しい", "古い"])
    }

    func test_insert後に件数が増える() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        XCTAssertEqual(try gateway.fetchCount(), 0)

        try gateway.insert(name: "1件目", tables: [], globalColumnCount: 2)

        XCTAssertEqual(try gateway.fetchCount(), 1)
        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["1件目"])
    }

    func test_ID指定で削除する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let newerID = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        try gateway.delete(ids: [newerID])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["古い"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_存在しないIDの削除は無視される() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        try gateway.delete(ids: [UUID()])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["残る"])
    }

    func test_複数IDで削除する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "真ん中", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let templates = try gateway.fetchSummaries()

        try gateway.delete(ids: [templates[0].id, templates[2].id])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["真ん中"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_空のID配列の削除は何もしない() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        try gateway.delete(ids: [])

        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["残る"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_ID指定で1件取得する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "宴会場", tables: [], globalColumnCount: 2)

        let inserted = try XCTUnwrap(gateway.fetchSummaries().first)
        let fetched = try XCTUnwrap(gateway.fetch(id: inserted.id))

        XCTAssertEqual(fetched.id, inserted.id)
        XCTAssertEqual(fetched.name, "宴会場")
        XCTAssertEqual(try gateway.fetchSummaries().map(\.id), [inserted.id])
    }

    func test_存在しないIDの取得はnil() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)

        XCTAssertNil(try gateway.fetch(id: UUID()))
    }

    private func makeSwiftDataGateway() throws -> (SwiftDataSeatingTemplateGateway, ModelContainer) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SeatingLayoutTemplate.self,
            configurations: configuration
        )
        return (SwiftDataSeatingTemplateGateway(context: ModelContext(container)), container)
    }
}

// MARK: - Interactor

final class SeatingTemplateInteractorTests: XCTestCase {

    func test_一覧は新しい順のSummaryを返す() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(
            name: "新しい",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
            ],
            globalColumnCount: 2
        )
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)

        let templates = try interactor.allTemplates()

        XCTAssertEqual(templates.map(\.name), ["新しい", "古い"])
        XCTAssertEqual(templates.first?.tableCountLabel, "テーブル数: 1")
    }

    func test_ID指定で削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)
        let newerID = try XCTUnwrap(interactor.allTemplates().first?.id)

        try interactor.deleteTemplates(ids: [newerID])

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["古い"])
    }

    func test_複数IDで削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "真ん中", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)
        let templates = try interactor.allTemplates()

        try interactor.deleteTemplates(ids: [templates[0].id, templates[2].id])

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["真ん中"])
    }

    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)

        try interactor.deleteTemplates(ids: [UUID()])

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["残る"])
    }

    func test_削除失敗はpersistenceFailedになる() {
        let interactor = SeatingTemplateInteractor(templateGateway: FailingDeleteSeatingTemplateGateway())

        XCTAssertThrowsError(try interactor.deleteTemplates(ids: [UUID()])) { error in
            XCTAssertEqual(
                error as? TemplateSaveError,
                .persistenceFailed(message: "削除に失敗しました")
            )
        }
    }

    func test_取得失敗はpersistenceFailedになる() {
        let interactor = SeatingTemplateInteractor(templateGateway: FailingFetchSeatingTemplateGateway())

        XCTAssertThrowsError(try interactor.allTemplates()) { error in
            XCTAssertEqual(
                error as? TemplateSaveError,
                .persistenceFailed(message: "読み込みに失敗しました")
            )
        }
    }

    func test_attachTemplateGatewayで永続化先を差し替える() throws {
        let first = InMemorySeatingTemplateGateway()
        try first.insert(name: "最初", tables: [], globalColumnCount: 2)
        let second = InMemorySeatingTemplateGateway()
        try second.insert(name: "差し替え後", tables: [], globalColumnCount: 2)
        let interactor = SeatingTemplateInteractor(templateGateway: first)

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["最初"])

        interactor.attachTemplateGateway(second)

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["差し替え後"])
    }
}

// MARK: - Presenter

@MainActor
final class SeatingTemplatePresenterTests: XCTestCase {

    private final class OutputSpy: SeatingTemplateModuleOutput {
        var selectedID: SeatingTemplateID?
        var cancelCount = 0

        func templateListDidSelect(id: SeatingTemplateID) { selectedID = id }
        func templateListDidCancel() { cancelCount += 1 }
    }

    private func makePresenter(
        gateway: SeatingTemplateGatewayBase,
        output: OutputSpy
    ) -> SeatingTemplatePresenter {
        SeatingTemplatePresenter(
            interactor: SeatingTemplateInteractor(templateGateway: gateway),
            output: output
        )
    }

    func test_onAppearで一覧をViewDataのRowに公開する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
            ],
            globalColumnCount: 2
        )
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)

        presenter.onAppear()

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["宴会場"])
        XCTAssertEqual(presenter.viewData.rows.map(\.tableCountLabel), ["テーブル数: 1"])
        XCTAssertFalse(presenter.viewData.isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_空ならisEmptyになる() {
        let presenter = makePresenter(gateway: InMemorySeatingTemplateGateway(), output: OutputSpy())

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertTrue(presenter.viewData.rows.isEmpty)
        XCTAssertNil(presenter.route)
    }

    func test_選択はOutputへ通知する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "宴会場", tables: [], globalColumnCount: 2)
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.didSelectTemplate(id: id)

        XCTAssertEqual(output.selectedID, id)
    }

    func test_選択はGatewayとViewDataを変えずOutputだけに通知する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "宴会場", tables: [], globalColumnCount: 2)
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchSummaries().first?.id)

        presenter.didSelectTemplate(id: id)

        XCTAssertEqual(output.selectedID, id)
        XCTAssertEqual(output.cancelCount, 0)
        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["宴会場"])
        XCTAssertEqual(try gateway.fetchSummaries().map(\.name), ["宴会場"])
        XCTAssertNil(presenter.route)
    }

    func test_取得失敗は空のViewDataとloadFailedのRouteになる() {
        let presenter = makePresenter(
            gateway: FailingFetchSeatingTemplateGateway(),
            output: OutputSpy()
        )

        presenter.onAppear()

        XCTAssertTrue(presenter.viewData.isEmpty)
        XCTAssertTrue(presenter.viewData.rows.isEmpty)
        XCTAssertEqual(
            presenter.route,
            .alert(.loadFailed(message: "読み込みに失敗しました"))
        )
    }

    func test_削除は一覧から消す() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "古い", tables: [], globalColumnCount: 2)
        try gateway.insert(name: "新しい", tables: [], globalColumnCount: 2)
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteTemplates(at: IndexSet(integer: 0))

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["古い"])
        XCTAssertNil(presenter.route)
    }

    func test_範囲外offsetの削除は一覧を変えない() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "残る", tables: [], globalColumnCount: 2)
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteTemplates(at: IndexSet(integer: 5))

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["残る"])
        XCTAssertNil(presenter.route)
    }

    func test_削除失敗はdeleteFailedのRouteになる() {
        let presenter = makePresenter(gateway: FailingDeleteSeatingTemplateGateway(), output: OutputSpy())

        presenter.didDeleteTemplates(at: IndexSet(integer: 0))

        XCTAssertEqual(
            presenter.route,
            .alert(.deleteFailed(message: "削除に失敗しました"))
        )
    }

    func test_dismissRouteで提示を閉じる() {
        let presenter = makePresenter(
            gateway: FailingFetchSeatingTemplateGateway(),
            output: OutputSpy()
        )
        XCTAssertNotNil(presenter.route)

        presenter.dismissRoute()

        XCTAssertNil(presenter.route)
    }

    func test_閉じるはOutputへキャンセルを通知する() {
        let output = OutputSpy()
        let presenter = makePresenter(gateway: InMemorySeatingTemplateGateway(), output: output)

        presenter.didTapClose()

        XCTAssertEqual(output.cancelCount, 1)
    }
}

// MARK: - Router

@MainActor
final class SeatingTemplateRouterTests: XCTestCase {

    func test_assemblePresenterは渡したGatewayから一覧を読む() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(name: "共有", tables: [], globalColumnCount: 2)
        XCTAssertEqual(gateway.fetchSummariesCallCount, 0)

        let presenter = SeatingTemplateRouter.assemblePresenter(
            gateway: gateway,
            output: nil
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchSummariesCallCount, 1)
        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["共有"])
    }

    func test_assembleのたびに新しいPresenterを返す() {
        let gateway = InMemorySeatingTemplateGateway()

        let first = SeatingTemplateRouter.assemblePresenter(gateway: gateway, output: nil)
        let second = SeatingTemplateRouter.assemblePresenter(gateway: gateway, output: nil)

        XCTAssertFalse(first === second)
    }

    func test_assembleModuleはSeatingTemplateViewを組み立てる() {
        let sheet = SeatingTemplateRouter.assembleModule(output: nil)

        XCTAssertTrue(
            seatingTemplateViewTreeContainsTypeName(sheet, "SeatingTemplateView"),
            "テンプレート一覧シートの中身は SeatingTemplateView である"
        )
    }
}

// MARK: - ViewData

final class SeatingTemplateViewDataTests: XCTestCase {
    func test_BuilderはSummaryのtableCountLabelをRowへ写す() {
        XCTAssertEqual(SeatingTemplateViewDataBuilder.build(templates: []), .empty)

        let one = LayoutTemplateSummary(
            id: UUID(),
            name: "宴会場",
            tableCountLabel: "テーブル数: 1"
        )
        let oneData = SeatingTemplateViewDataBuilder.build(templates: [one])
        XCTAssertEqual(oneData.rows.map(\.id), [one.id])
        XCTAssertEqual(oneData.rows.map(\.name), ["宴会場"])
        XCTAssertEqual(oneData.rows.map(\.tableCountLabel), ["テーブル数: 1"])
        XCTAssertFalse(oneData.isEmpty)

        let three = [
            LayoutTemplateSummary(id: UUID(), name: "カフェ", tableCountLabel: "テーブル数: 0"),
            LayoutTemplateSummary(id: UUID(), name: "教室", tableCountLabel: "テーブル数: 2"),
            LayoutTemplateSummary(id: UUID(), name: "宴会場", tableCountLabel: "テーブル数: 1")
        ]
        let threeData = SeatingTemplateViewDataBuilder.build(templates: three)
        XCTAssertEqual(threeData.rows.map(\.name), ["カフェ", "教室", "宴会場"])
        XCTAssertEqual(threeData.rows.map(\.tableCountLabel), ["テーブル数: 0", "テーブル数: 2", "テーブル数: 1"])
        XCTAssertEqual(threeData.rows.count, 3)
    }
}

// MARK: - View

@MainActor
final class SeatingTemplateViewTests: XCTestCase {
    func test_bodyはEmptyStateViewとSavedListRowとSheetChromeToolbarを使う() {
        let view = SeatingTemplateView(
            presenter: SeatingTemplateRouter.assemblePresenter(
                gateway: InMemorySeatingTemplateGateway(),
                output: nil
            )
        )
        let body = view.body

        XCTAssertTrue(
            seatingTemplateViewTreeContainsTypeName(body, "EmptyStateView"),
            "空状態は List 内 EmptyStateView"
        )
        XCTAssertTrue(
            seatingTemplateViewTreeContainsTypeName(body, "SavedListRow"),
            "行は素の SavedListRow"
        )
        XCTAssertTrue(
            seatingTemplateViewTreeContainsTypeName(body, "SheetChromeToolbar"),
            "クロムは SheetChromeToolbar"
        )
    }

    func test_3件のPresenterは件数ラベルのRowを公開する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(name: "宴会場", tables: [], globalColumnCount: 2)
        try gateway.insert(
            name: "教室",
            tables: [
                TableTemplate(name: "前列", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: ""),
                TableTemplate(name: "後列", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
            ],
            globalColumnCount: 2
        )
        try gateway.insert(name: "カフェ", tables: [], globalColumnCount: 2)
        let presenter = SeatingTemplateRouter.assemblePresenter(gateway: gateway, output: nil)

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["カフェ", "教室", "宴会場"])
        XCTAssertEqual(
            presenter.viewData.rows.map(\.tableCountLabel),
            ["テーブル数: 0", "テーブル数: 2", "テーブル数: 0"]
        )
        XCTAssertFalse(presenter.viewData.isEmpty)
    }
}

// MARK: - Copy

final class SeatingTemplateCopyTests: XCTestCase {
    func test_文言は既存Catalogキーのまま() {
        XCTAssertEqual(SeatingTemplateCopy.navigationTitle, "テンプレート読込")
        XCTAssertEqual(SeatingTemplateCopy.emptyMessage, "保存されたテンプレートはありません")
        XCTAssertEqual(SeatingTemplateCopy.edit, "編集")
        XCTAssertEqual(SeatingTemplateCopy.close, "閉じる")
        XCTAssertEqual(SeatingTemplateCopy.ok, "OK")
        XCTAssertEqual(SeatingTemplateCopy.deleteFailedTitle, "削除に失敗しました")
        XCTAssertEqual(SeatingTemplateCopy.loadFailedTitle, "読み込みに失敗しました")
        XCTAssertEqual(SeatingTemplateCopy.tableCountLabel(2), "テーブル数: 2")
    }

    func test_閉じる編集空状態のHintはFavoriteGroupと対になる() {
        XCTAssertEqual(SeatingTemplateCopy.closeAccessibilityHint, "保存済みテンプレートの一覧を閉じます")
        XCTAssertEqual(SeatingTemplateCopy.editAccessibilityHint, "テンプレートを削除できるようにします")
        XCTAssertEqual(SeatingTemplateCopy.done, "完了")
        XCTAssertEqual(SeatingTemplateCopy.doneAccessibilityHint, "編集を終了します")
        XCTAssertEqual(SeatingTemplateCopy.emptyAccessibilityHint, "閉じるボタンで座席表に戻ります")
        XCTAssertEqual(SeatingTemplateCopy.editingSelectDisabledHint, "編集中は読み込みできません")
        XCTAssertEqual(SeatingTemplateCopy.selectAccessibilityHint, "このテンプレートを座席表に読み込みます")
    }

    func test_行のHintは編集中に読み込み案内を出さない() {
        XCTAssertEqual(
            SeatingTemplateCopy.rowAccessibilityHint(isEditing: false),
            "このテンプレートを座席表に読み込みます"
        )
        XCTAssertEqual(
            SeatingTemplateCopy.rowAccessibilityHint(isEditing: true),
            "編集中は読み込みできません"
        )
    }

    func test_編集トグルのLabelとHintは完了時に切り替わる() {
        XCTAssertEqual(SeatingTemplateCopy.editAccessibilityLabel(isEditing: false), "編集")
        XCTAssertEqual(SeatingTemplateCopy.editAccessibilityLabel(isEditing: true), "完了")
        XCTAssertEqual(
            SeatingTemplateCopy.editButtonAccessibilityHint(isEditing: false),
            "テンプレートを削除できるようにします"
        )
        XCTAssertEqual(
            SeatingTemplateCopy.editButtonAccessibilityHint(isEditing: true),
            "編集を終了します"
        )
    }

    func test_失敗アラートのタイトルはCatalogにある() {
        XCTAssertEqual(SeatingTemplateCopy.deleteFailedTitle, String(localized: "削除に失敗しました"))
        XCTAssertEqual(SeatingTemplateCopy.loadFailedTitle, String(localized: "読み込みに失敗しました"))
    }

    func test_A11yHintはCatalogキーと一致する() {
        XCTAssertEqual(
            SeatingTemplateCopy.closeAccessibilityHint,
            String(localized: "保存済みテンプレートの一覧を閉じます")
        )
        XCTAssertEqual(
            SeatingTemplateCopy.selectAccessibilityHint,
            String(localized: "このテンプレートを座席表に読み込みます")
        )
        XCTAssertEqual(
            SeatingTemplateCopy.emptyAccessibilityHint,
            String(localized: "閉じるボタンで座席表に戻ります")
        )
        XCTAssertEqual(
            SeatingTemplateCopy.editAccessibilityHint,
            String(localized: "テンプレートを削除できるようにします")
        )
        XCTAssertEqual(
            SeatingTemplateCopy.editingSelectDisabledHint,
            String(localized: "編集中は読み込みできません")
        )
        XCTAssertEqual(
            SeatingTemplateCopy.doneAccessibilityHint,
            String(localized: "編集を終了します")
        )
    }
}

// MARK: - Helpers

private final class FailingFetchSeatingTemplateGateway: SeatingTemplateGatewayBase {
    override func fetchCount() throws -> Int {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }

    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }

    override func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot? {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }
}

private final class FailingDeleteSeatingTemplateGateway: SeatingTemplateGatewayBase {
    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        [LayoutTemplateSummary(id: UUID(), name: "宴会場", tableCountLabel: "テーブル数: 0")]
    }

    override func delete(ids: [SeatingTemplateID]) throws {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "削除に失敗しました"]
        )
    }
}

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

private func seatingTemplateViewTreeContainsTypeName(_ value: Any, _ name: String, depth: Int = 0) -> Bool {
    guard depth < 16 else { return false }
    if String(describing: type(of: value)).contains(name) {
        return true
    }
    for child in Mirror(reflecting: value).children {
        if seatingTemplateViewTreeContainsTypeName(child.value, name, depth: depth + 1) {
            return true
        }
    }
    return false
}
