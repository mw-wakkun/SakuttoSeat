//
//  SeatingChartRouterTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0（テンプレート一覧の組み立てを固定）
//
//  `_既知の課題`: `makeTemplateListModule` は Gateway を受け取らず、
//  素の `SeatingTemplateListView`（`@Query`）を包むだけ。子 VIPER 化は Phase 2。
//

import SwiftUI
import XCTest
@testable import SakuttoSeat

@MainActor
final class SeatingChartRouterTests: XCTestCase {

    func test_makeTemplateListModuleはSeatingTemplateListViewを組み立てる() {
        let router = SeatingChartRouter()
        let output = TemplateListOutputSpy()

        let sheet = router.makeTemplateListModule(output: output)

        XCTAssertTrue(
            viewTreeContainsTypeName(sheet, "SeatingTemplateListView"),
            "テンプレート一覧シートの中身は SeatingTemplateListView である"
        )
    }

    func test_RouterProtocol経由でもテンプレート一覧を組み立てる() {
        let router: any SeatingChartRouterProtocol = SeatingChartRouter()

        let sheet = router.makeTemplateListModule(output: TemplateListOutputSpy())

        XCTAssertTrue(viewTreeContainsTypeName(sheet, "SeatingTemplateListView"))
    }

    func test_同じoutputで2回makeしても組み立てられる() {
        let router = SeatingChartRouter()
        let output = TemplateListOutputSpy()

        _ = router.makeTemplateListModule(output: output)
        _ = router.makeTemplateListModule(output: output)
    }

    /// `_既知の課題`: 親 Interactor の Gateway を一覧へ渡せない。組み立ては fetch しない。
    func test_既知の課題_一覧組み立てはGatewayを読まない() throws {
        let gateway = FetchCountingSeatingTemplateGateway()
        try gateway.insert(
            SeatingLayoutTemplate(name: "共有", tables: [], globalColumnCount: 2)
        )
        XCTAssertEqual(gateway.fetchAllCallCount, 0)

        _ = SeatingChartRouter().makeTemplateListModule(output: TemplateListOutputSpy())

        XCTAssertEqual(gateway.fetchAllCallCount, 0)
    }
}

@MainActor
private final class TemplateListOutputSpy: TemplateListModuleOutput {
    var selected: SeatingLayoutTemplate?
    var cancelCount = 0

    func templateListDidSelect(template: SeatingLayoutTemplate) {
        selected = template
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
