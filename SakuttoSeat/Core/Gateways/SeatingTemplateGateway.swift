//
//  SeatingTemplateGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//  refactor_templateListView.md Phase 0
//
//  Protocol existential をクラスが保持すると deinit で malloc abort するため、
//  Interactor は具象基底クラスだけを保持する。
//
//  `_既知の課題`: 本番の一覧削除は `SeatingTemplateListView` の `modelContext.delete`。
//  この Gateway の `delete(id:)` は保存経路以外から呼ばれない（Phase 2 で子へ移す）。
//

import Foundation
import SwiftData

/// `nonisolated`: 要件が MainActor 隔離だと、それを満たす具象側のメソッドも
/// MainActor 隔離と推論され、`nonisolated` な Interactor から呼べなくなるため。
nonisolated protocol SeatingTemplateGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [SeatingLayoutTemplate]
    func insert(_ template: SeatingLayoutTemplate) throws
    func delete(id: UUID) throws
}

nonisolated class SeatingTemplateGatewayBase: SeatingTemplateGateway {
    func fetchCount() throws -> Int { 0 }
    func fetchAll() throws -> [SeatingLayoutTemplate] { [] }
    func insert(_ template: SeatingLayoutTemplate) throws {}
    func delete(id: UUID) throws {}
}

nonisolated final class SwiftDataSeatingTemplateGateway: SeatingTemplateGatewayBase {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    override func fetchCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<SeatingLayoutTemplate>())
    }

    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    override func insert(_ template: SeatingLayoutTemplate) throws {
        context.insert(template)
        try context.save()
    }

    override func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        for template in try context.fetch(descriptor) {
            context.delete(template)
        }
        try context.save()
    }
}

nonisolated final class InMemorySeatingTemplateGateway: SeatingTemplateGatewayBase {
    private(set) var templates: [SeatingLayoutTemplate] = []

    override func fetchCount() throws -> Int { templates.count }

    override func fetchAll() throws -> [SeatingLayoutTemplate] {
        templates.sorted { $0.createdAt > $1.createdAt }
    }

    override func insert(_ template: SeatingLayoutTemplate) throws {
        templates.append(template)
    }

    override func delete(id: UUID) throws {
        templates.removeAll { $0.id == id }
    }
}
