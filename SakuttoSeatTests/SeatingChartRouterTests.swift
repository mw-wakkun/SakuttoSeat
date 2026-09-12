//
//  SeatingChartRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0 / Phase 2 / Phase 3
//  refactor_templateListView.md Phase 4（Router はキャッシュしない。シート identity は親 Presenter）
//  テンプレート一覧は子 VIPER に委譲する。Gateway は gatewayHolder から読む。
//

import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartRouterTests: XCTestCase {

    func test_一覧組み立ては渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(name: "共有", tables: [], globalColumnCount: 2)
        XCTAssertEqual(gateway.fetchSummariesCallCount, 0)
        let gatewayHolder = SeatingChartInteractor(templateGateway: gateway)

        let presenter = SeatingChartRouter().makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )
        _ = SeatingChartRouter().makeTemplateListSheet(presenter: presenter)
        _ = SeatingChartRouter().makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )
        _ = SeatingTemplateRouter.assembleModule(
            gateway: gateway,
            output: TemplateListOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchSummariesCallCount, 3)
    }

    func test_makeTemplateListPresenterはassembleのたびに新しいPresenterを返す() {
        let gatewayHolder = SeatingChartInteractor()
        let output = TemplateListOutputSpy()

        let first = SeatingChartRouter().makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: output
        )
        let second = SeatingChartRouter().makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: output
        )

        XCTAssertFalse(first === second)
    }
}

@MainActor
private final class TemplateListOutputSpy: SeatingTemplateModuleOutput {
    var selectedID: SeatingTemplateID?
    var cancelCount = 0

    func templateListDidSelect(id: SeatingTemplateID) {
        selectedID = id
    }

    func templateListDidCancel() {
        cancelCount += 1
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
