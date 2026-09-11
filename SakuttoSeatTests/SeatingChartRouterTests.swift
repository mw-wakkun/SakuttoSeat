//
//  SeatingChartRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0 / Phase 2
//  テンプレート一覧は子 VIPER に委譲する。シート identity は Phase 4。
//

import SwiftUI
import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartRouterTests: XCTestCase {

    func test_makeTemplateListModuleはSeatingTemplateViewを組み立てる() {
        let router = SeatingChartRouter()
        let output = TemplateListOutputSpy()

        let sheet = router.makeTemplateListModule(
            gateway: InMemorySeatingTemplateGateway(),
            output: output
        )

        XCTAssertTrue(
            viewTreeContainsTypeName(sheet, "SeatingTemplateView"),
            "テンプレート一覧シートの中身は SeatingTemplateView である"
        )
    }

    func test_RouterProtocol経由でもテンプレート一覧を組み立てる() {
        let router: any SeatingChartRouterProtocol = SeatingChartRouter()

        let sheet = router.makeTemplateListModule(
            gateway: InMemorySeatingTemplateGateway(),
            output: TemplateListOutputSpy()
        )

        XCTAssertTrue(viewTreeContainsTypeName(sheet, "SeatingTemplateView"))
    }

    func test_同じoutputで2回makeしても組み立てられる() {
        let router = SeatingChartRouter()
        let gateway = InMemorySeatingTemplateGateway()
        let output = TemplateListOutputSpy()

        _ = router.makeTemplateListModule(gateway: gateway, output: output)
        _ = router.makeTemplateListModule(gateway: gateway, output: output)
    }

    func test_一覧組み立ては渡したGatewayインスタンスから一覧を読む() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(
            SeatingLayoutTemplate(name: "共有", tables: [], globalColumnCount: 2)
        )
        XCTAssertEqual(gateway.fetchAllCallCount, 0)

        _ = SeatingChartRouter().makeTemplateListModule(
            gateway: gateway,
            output: TemplateListOutputSpy()
        )
        _ = SeatingTemplateRouter.assembleModule(
            gateway: gateway,
            output: TemplateListOutputSpy()
        )

        XCTAssertGreaterThanOrEqual(gateway.fetchAllCallCount, 2)
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
    private var stored: [SeatingLayoutTemplate] = []
    private(set) var fetchAllCallCount = 0

    override func fetchCount() throws -> Int { stored.count }

    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        fetchAllCallCount += 1
        return stored
    }

    override func insert(_ template: SeatingLayoutTemplate) throws {
        stored.append(template)
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
