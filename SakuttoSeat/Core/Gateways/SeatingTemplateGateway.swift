//
//  SeatingTemplateGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//  refactor_templateListView.md Phase 3（Snapshot 戻り / fetch(id:) / delete(ids:) / insert(fields)）
//
//  画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate。@Model はこのファイル内に閉じる。
//  Protocol existential をクラスが保持すると deinit で malloc abort するため、
//  Interactor は具象基底クラスだけを保持する。
//

import Foundation
import SwiftData

/// `nonisolated`: 要件が MainActor 隔離だと、それを満たす具象側のメソッドも
/// MainActor 隔離と推論され、`nonisolated` な Interactor から呼べなくなるため。
nonisolated protocol SeatingTemplateGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [LayoutTemplateSnapshot]
    func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot?
    func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws
    func delete(ids: [SeatingTemplateID]) throws
}

nonisolated class SeatingTemplateGatewayBase: SeatingTemplateGateway {
    func fetchCount() throws -> Int { 0 }
    func fetchAll() throws -> [LayoutTemplateSnapshot] { [] }
    func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot? { nil }
    func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws {}
    func delete(ids: [SeatingTemplateID]) throws {}
}

nonisolated final class SwiftDataSeatingTemplateGateway: SeatingTemplateGatewayBase {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    override func fetchCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<SeatingLayoutTemplate>())
    }

    override func fetchAll() throws -> [LayoutTemplateSnapshot] {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.makeSnapshot() }
    }

    override func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot? {
        try fetchModel(id: id)?.makeSnapshot()
    }

    override func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws {
        context.insert(SeatingLayoutTemplate(name: name, tables: tables, globalColumnCount: globalColumnCount))
        try context.save()
    }

    override func delete(ids: [SeatingTemplateID]) throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            if let template = try fetchModel(id: id) {
                context.delete(template)
            }
        }
        try context.save()
    }

    private func fetchModel(id: SeatingTemplateID) throws -> SeatingLayoutTemplate? {
        let targetID = id
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>(
            predicate: #Predicate { $0.id == targetID }
        )
        return try context.fetch(descriptor).first
    }
}

nonisolated final class InMemorySeatingTemplateGateway: SeatingTemplateGatewayBase {
    private var records: [Record] = []
    /// 同一瞬間の連続 insert でも新しい順が崩れないようにする
    private var nextCreatedAt: TimeInterval = 0

    override func fetchCount() throws -> Int { records.count }

    override func fetchAll() throws -> [LayoutTemplateSnapshot] {
        records.sorted { $0.createdAt > $1.createdAt }.map(\.snapshot)
    }

    override func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot? {
        records.first { $0.snapshot.id == id }?.snapshot
    }

    override func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws {
        nextCreatedAt += 1
        records.append(
            Record(
                snapshot: LayoutTemplateSnapshot(
                    name: name,
                    tables: tables,
                    globalColumnCount: globalColumnCount
                ),
                createdAt: Date(timeIntervalSince1970: nextCreatedAt)
            )
        )
    }

    override func delete(ids: [SeatingTemplateID]) throws {
        let idSet = Set(ids)
        records.removeAll { idSet.contains($0.snapshot.id) }
    }

    private struct Record {
        let snapshot: LayoutTemplateSnapshot
        let createdAt: Date
    }
}

extension SeatingLayoutTemplate {
    fileprivate func makeSnapshot() -> LayoutTemplateSnapshot {
        LayoutTemplateSnapshot(
            id: id,
            name: name,
            tables: tables,
            globalColumnCount: globalColumnCount
        )
    }
}
