//
//  SeatingChartRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0 / Phase 2 / Phase 3
//  refactor_templateListView.md Phase 4（Router はキャッシュしない。シート identity は親 Presenter）
//  テンプレート一覧は子 VIPER に委譲する。Gateway は gatewayHolder から読む。
//

import SwiftUI
import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartRouterTests: XCTestCase {

    func test_assembleModuleは参加者を受け取って画面を返す() {
        _ = SeatingChartRouter.assembleModule(attendees: [Attendee(name: "A")])
        _ = SeatingChartRouter.assembleModule(
            attendees: [],
            templateGateway: InMemorySeatingTemplateGateway()
        )
    }

    func test_makeTemplateListModuleはSeatingTemplateViewを組み立てる() {
        let router = SeatingChartRouter()
        let output = TemplateListOutputSpy()

        let sheet = router.makeTemplateListModule(
            gatewayHolder: SeatingChartInteractor(),
            output: output
        )

        XCTAssertTrue(
            viewTreeContainsTypeName(sheet, "SeatingTemplateView"),
            "テンプレート一覧シートの中身は SeatingTemplateView である"
        )
    }

    func test_RouterProtocol経由でもテンプレート一覧を組み立てる() {
        let router: any SeatingChartRouterProtocol = SeatingChartRouter()
        let gatewayHolder = SeatingChartInteractor()

        let sheet = router.makeTemplateListModule(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )

        XCTAssertTrue(viewTreeContainsTypeName(sheet, "SeatingTemplateView"))
        _ = router.makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )
        _ = router.makeTemplateListSheet(
            presenter: SeatingTemplateRouter.assemblePresenter(output: nil)
        )
    }

    func test_同じoutputで2回makeしても組み立てられる() {
        let router = SeatingChartRouter()
        let gatewayHolder = SeatingChartInteractor()
        let output = TemplateListOutputSpy()

        _ = router.makeTemplateListModule(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeTemplateListModule(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeTemplateListPresenter(gatewayHolder: gatewayHolder, output: output)
        _ = router.makeTemplateListPresenter(gatewayHolder: gatewayHolder, output: output)
    }

    func test_一覧組み立ては渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(name: "共有", tables: [], globalColumnCount: 2)
        XCTAssertEqual(gateway.fetchAllCallCount, 0)
        let gatewayHolder = SeatingChartInteractor(templateGateway: gateway)

        _ = SeatingChartRouter().makeTemplateListModule(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )
        _ = SeatingChartRouter().makeTemplateListPresenter(
            gatewayHolder: gatewayHolder,
            output: TemplateListOutputSpy()
        )
        _ = SeatingTemplateRouter.assembleModule(
            gateway: gateway,
            output: TemplateListOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchAllCallCount, 3)
    }

    func test_makeTemplateListSheetはSeatingTemplateViewを包む() {
        let presenter = SeatingTemplateRouter.assemblePresenter(output: nil)

        let sheet = SeatingChartRouter().makeTemplateListSheet(presenter: presenter)

        XCTAssertTrue(viewTreeContainsTypeName(sheet, "SeatingTemplateView"))
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
    private var stored: [LayoutTemplateSnapshot] = []
    private(set) var fetchAllCallCount = 0

    override func fetchCount() throws -> Int { stored.count }

    override func fetchAll() throws -> [LayoutTemplateSnapshot] {
        fetchAllCallCount += 1
        return stored
    }

    override func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws {
        stored.append(LayoutTemplateSnapshot(name: name, tables: tables, globalColumnCount: globalColumnCount))
    }
}

private func viewTreeContainsTypeName(_ value: Any, _ name: String, depth: Int = 0) -> Bool {
    guard depth < 8 else { return false }
    if String(describing: type(of: value)).contains(name) {
        return true
    }
    for child in Mirror(reflecting: value).children {
        if viewTreeContainsTypeName(child.value, name, depth: depth + 1) {
            return true
        }
    }
    return false
}
