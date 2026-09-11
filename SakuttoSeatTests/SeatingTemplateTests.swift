//
//  SeatingTemplateTests.swift
//  SakuttoSeatTests
//
//  refactor_templateListView.md Phase 0（Gateway と親テンプレ経路の characterization）
//
//  子 VIPER は未導入。一覧・削除の本番経路は View の `@Query` / `modelContext.delete`。
//  ここでは Gateway API と、テスト可能な親経路だけを固定する。
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

    /// `_既知の課題`: 一覧の削除は `SeatingTemplateListView` が `modelContext.delete` しており、
    /// Gateway の `delete(id:)` は保存経路以外から本番で呼ばれない。
    func test_存在しないIDの削除は無視される() throws {
        let gateway = InMemorySeatingTemplateGateway()
        try gateway.insert(makeTemplate(name: "残る"))

        try gateway.delete(id: UUID())

        XCTAssertEqual(try gateway.fetchAll().map(\.name), ["残る"])
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

    private func makeSwiftDataGateway() throws -> (SwiftDataSeatingTemplateGateway, ModelContainer) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SeatingLayoutTemplate.self,
            configurations: configuration
        )
        return (SwiftDataSeatingTemplateGateway(context: ModelContext(container)), container)
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

