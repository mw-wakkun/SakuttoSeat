//
//  SeatingTemplateGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//  refactor_templateListView.md Phase 3（Snapshot 戻り / fetch(id:) / delete(ids:) / insert(fields)）
//  refactor_groupFavorite.md Phase 3 相当（fetchSummaries / 一括削除。fetchAll は削除）
//
//  画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate。@Model は Core/Persistence。
//  Protocol existential をクラスが保持すると deinit で malloc abort するため、
//  Interactor は具象基底クラスだけを保持する。
//  一覧は fetchSummaries、読込適用は fetch(id:)。件数は Gateway が一覧 DTO に載せる。
//  本番経路は @MainActor Presenter からのみ呼ぶ。型に @MainActor は付けない
//  （nonisolated Interactor 規約と衝突するため）。
//

import Foundation
import SwiftData

/// `nonisolated`: 要件が MainActor 隔離だと、それを満たす具象側のメソッドも
/// MainActor 隔離と推論され、`nonisolated` な Interactor から呼べなくなるため。
/// オフトレッドからの呼び出しは未定義。本番は MainActor Presenter 経由のみ。
nonisolated protocol SeatingTemplateGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchSummaries() throws -> [LayoutTemplateSummary]
    func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot?
    func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws
    func delete(ids: [SeatingTemplateID]) throws
}

nonisolated class SeatingTemplateGatewayBase: SeatingTemplateGateway {
    func fetchCount() throws -> Int { 0 }
    func fetchSummaries() throws -> [LayoutTemplateSummary] { [] }
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

    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        let descriptor = FetchDescriptor<SeatingLayoutTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.makeSummary() }
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
        // 無料枠は 3 件。SwiftData の #Predicate は外部配列の contains を安定して
        // 扱えないため、全件 1 fetch + Set 判定で対象を集め、まとめて delete する。
        // save は 1 回。ID ごとの fetchModel はしない（N+1 回避）。
        let idSet = Set(ids)
        let templates = try context.fetch(FetchDescriptor<SeatingLayoutTemplate>())
        for template in templates where idSet.contains(template.id) {
            context.delete(template)
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

    override func fetchSummaries() throws -> [LayoutTemplateSummary] {
        records
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.snapshot.makeSummary() }
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

nonisolated extension SeatingLayoutTemplate {
    fileprivate func makeSnapshot() -> LayoutTemplateSnapshot {
        LayoutTemplateSnapshot(
            id: id,
            name: name,
            tables: tables,
            globalColumnCount: globalColumnCount
        )
    }

    fileprivate func makeSummary() -> LayoutTemplateSummary {
        LayoutTemplateListingSummary.listing(id: id, name: name, tableCount: tables.count)
    }
}

nonisolated extension LayoutTemplateSnapshot {
    fileprivate func makeSummary() -> LayoutTemplateSummary {
        LayoutTemplateListingSummary.listing(id: id, name: name, tableCount: tables.count)
    }
}

/// 件数は Gateway ファイル内だけが担う（Builder は写すだけ）。
nonisolated private enum LayoutTemplateListingSummary {
    static func listing(
        id: SeatingTemplateID,
        name: String,
        tableCount: Int
    ) -> LayoutTemplateSummary {
        LayoutTemplateSummary(
            id: id,
            name: name,
            tableCountLabel: SeatingTemplateCopy.tableCountLabel(tableCount)
        )
    }
}
