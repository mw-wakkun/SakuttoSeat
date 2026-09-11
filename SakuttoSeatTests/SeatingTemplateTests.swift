//
//  SeatingTemplateTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0（Gateway の characterization）
//  refactor_templateListView.md Phase 2（子 VIPER の一覧・削除・Output・取得失敗）
//

import SwiftData
import XCTest
@testable import SakuttoSeat

// MARK: - Gateway（In-Memory）

final class SeatingTemplateGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["新しい", "古い"])
    }

    func test_insert後に件数が増える() throws {
        let gateway = InMemorySeatingTemplateGateway()
        XCTAssertEqual(try gateway.fetchCount(), 0)

        try gateway.insert(makeTemplate(name: "1件目"))

        XCTAssertEqual(try gateway.fetchCount(), 1)
        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["1件目"])
    }

    func test_ID指定で削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))
        let newerID = try XCTUnwrap(gateway.fetchAll().first?.id)

        try gateway.delete(id: newerID)

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["古い"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "残る"))

        try gateway.delete(id: UUID())

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
    }

    func test_ID指定で1件取得する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        let template = makeTemplate(
            name: "宴会場",
            tables: [
                TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .left, layoutText: "入り口側")
            ]
        )
        try gateway.insert(template)

        let fetched = try XCTUnwrap(gateway.fetch(id: template.id))

        XCTAssertEqual(fetched.id, template.id)
        XCTAssertEqual(fetched.name, "宴会場")
        XCTAssertEqual(fetched.tables.map(\.name), ["受付卓"])
        XCTAssertEqual(fetched.globalColumnCount, 2)
    }

    func test_存在しないIDの取得はnil() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "残る"))

        XCTAssertNil(try gateway.fetch(id: UUID()))
    }
}

// MARK: - Gateway（SwiftData In-Memory）

@MainActor
final class SwiftDataSeatingTemplateGatewayTests: XCTestCase {

    func test_一覧は新しい順を返す() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["新しい", "古い"])
    }

    func test_insert後に件数が増える() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        XCTAssertEqual(try gateway.fetchCount(), 0)

        try gateway.insert(makeTemplate(name: "1件目"))

        XCTAssertEqual(try gateway.fetchCount(), 1)
        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["1件目"])
    }

    func test_ID指定で削除する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))
        let newerID = try XCTUnwrap(gateway.fetchAll().first?.id)

        try gateway.delete(id: newerID)

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["古い"])
        XCTAssertEqual(try gateway.fetchCount(), 1)
    }

    func test_存在しないIDの削除は無視される() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(makeTemplate(name: "残る"))

        try gateway.delete(id: UUID())

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
    }

    func test_ID指定で1件取得する() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        let template = makeTemplate(name: "宴会場")
        try gateway.insert(template)

        let fetched = try XCTUnwrap(gateway.fetch(id: template.id))

        XCTAssertEqual(fetched.id, template.id)
        XCTAssertEqual(fetched.name, "宴会場")
    }

    func test_存在しないIDの取得はnil() throws {
        let (gateway, container) = try makeSwiftDataGateway()
        _ = container
        try gateway.insert(makeTemplate(name: "残る"))

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

    func test_一覧は新しい順のスナップショットを返す() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(
            makeTemplate(
                name: "新しい",
                createdAt: Date(timeIntervalSince1970: 2),
                tables: [
                    TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
                ]
            )
        )
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)

        let templates = try interactor.allTemplates()

        XCTAssertEqual(templates.map(\.name), ["新しい", "古い"])
        XCTAssertEqual(templates.first?.id, gateway.templates.last?.id)
        XCTAssertEqual(templates.first?.tables.map(\.name), ["受付卓"])
        XCTAssertEqual(templates.first?.globalColumnCount, 2)
    }

    func test_ID指定で削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)
        let newerID = try XCTUnwrap(interactor.allTemplates().first?.id)

        try interactor.deleteTemplates(ids: [newerID])

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["古い"])
    }

    func test_複数IDで削除する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "真ん中", createdAt: Date(timeIntervalSince1970: 2)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 3)))
        let interactor = SeatingTemplateInteractor(templateGateway: gateway)
        let templates = try interactor.allTemplates()

        try interactor.deleteTemplates(ids: [templates[0].id, templates[2].id])

        XCTAssertEqual(try interactor.allTemplates().map(\.name), ["真ん中"])
    }

    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "残る"))
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
        try first.insert(makeTemplate(name: "最初"))
        let second = InMemorySeatingTemplateGateway()
        try second.insert(makeTemplate(name: "差し替え後"))
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
            makeTemplate(
                name: "宴会場",
                tables: [
                    TableTemplate(name: "受付卓", capacity: 3, columnCount: 3, layoutDirection: .none, layoutText: "")
                ]
            )
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
        try gateway.insert(makeTemplate(name: "宴会場"))
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchAll().first?.id)

        presenter.didSelectTemplate(id: id)

        XCTAssertEqual(output.selectedID, id)
    }

    func test_選択はGatewayとViewDataを変えずOutputだけに通知する() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "宴会場"))
        let output = OutputSpy()
        let presenter = makePresenter(gateway: gateway, output: output)
        let id = try XCTUnwrap(gateway.fetchAll().first?.id)

        presenter.didSelectTemplate(id: id)

        XCTAssertEqual(output.selectedID, id)
        XCTAssertEqual(output.cancelCount, 0)
        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["宴会場"])
        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["宴会場"])
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
        try gateway.insert(makeTemplate(name: "古い", createdAt: Date(timeIntervalSince1970: 1)))
        try gateway.insert(makeTemplate(name: "新しい", createdAt: Date(timeIntervalSince1970: 2)))
        let presenter = makePresenter(gateway: gateway, output: OutputSpy())

        presenter.didDeleteTemplates(at: IndexSet(integer: 0))

        XCTAssertEqual(presenter.viewData.rows.map(\.name), ["古い"])
        XCTAssertNil(presenter.route)
    }

    func test_範囲外offsetの削除は一覧を変えない() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "残る"))
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
        try gateway.insert(makeTemplate(name: "共有"))
        XCTAssertEqual(gateway.fetchAllCallCount, 0)

        let presenter = SeatingTemplateRouter.assemblePresenter(
            gateway: gateway,
            output: nil
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchAllCallCount, 1)
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

    func test_失敗アラートのタイトルはCatalogにある() {
        XCTAssertEqual(SeatingTemplateCopy.deleteFailedTitle, String(localized: "削除に失敗しました"))
        XCTAssertEqual(SeatingTemplateCopy.loadFailedTitle, String(localized: "読み込みに失敗しました"))
    }
}

// MARK: - Helpers

private func makeTemplate(
    name: String,
    createdAt: Date = Date(),
    tables: [TableTemplate] = []
) -> SeatingLayoutTemplate {
    SeatingLayoutTemplate(
        name: name,
        tables: tables,
        globalColumnCount: 2,
        createdAt: createdAt
    )
}

private final class FailingFetchSeatingTemplateGateway: SeatingTemplateGatewayBase {
    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "読み込みに失敗しました"]
        )
    }
}

private final class FailingDeleteSeatingTemplateGateway: SeatingTemplateGatewayBase {
    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        [makeTemplate(name: "宴会場")]
    }

    override func delete(id: UUID) throws {
        throw NSError(
            domain: "SeatingTemplateTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "削除に失敗しました"]
        )
    }
}

private final class FetchCountingSeatingTemplateGateway: SeatingTemplateGatewayBase {
    private var stored: [SeatingLayoutTemplate] = []
    private(set) var fetchAllCallCount = 0

    override func fetchCount() throws -> Int { stored.count }

    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        fetchAllCallCount += 1
        return stored.sorted { $0.createdAt > $1.createdAt }
    }

    override func insert(_ template: SeatingLayoutTemplate) throws {
        stored.append(template)
    }
}

private func seatingTemplateViewTreeContainsTypeName(_ value: Any, _ name: String, depth: Int = 0) -> Bool {
    guard depth < 8 else { return false }
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
