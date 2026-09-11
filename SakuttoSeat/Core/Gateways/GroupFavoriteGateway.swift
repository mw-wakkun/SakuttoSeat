//
//  GroupFavoriteGateway.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4
//  refactor_favorite.md Phase 3（Snapshot 戻り / fetch(id:) / delete(ids:) / insert(name:members:)）
//  refactor_groupFavorite.md Phase 1（@Model の住所は Core/Persistence。型名は変えない）
//  refactor_groupFavorite.md Phase 3（fetchSummaries / 一括削除。fetchAll は削除）
//
//  画面 = FavoriteGroup、永続化 = GroupFavorite。@Model は Core/Persistence。
//  Protocol existential をクラスが保持すると deinit で malloc abort するため、
//  Interactor は具象基底クラスだけを保持する。
//  一覧は fetchSummaries、読込置換は fetch(id:)。字幕結合は Gateway だけが担う。
//

import Foundation
import SwiftData

/// `nonisolated`: 要件が MainActor 隔離だと、それを満たす具象側のメソッドも
/// MainActor 隔離と推論され、`nonisolated` な Interactor から呼べなくなるため。
nonisolated protocol GroupFavoriteGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchSummaries() throws -> [FavoriteGroupSummary]
    func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot?
    func insert(name: String, members: [String]) throws
    func delete(ids: [FavoriteGroupID]) throws
}

nonisolated class GroupFavoriteGatewayBase: GroupFavoriteGateway {
    func fetchCount() throws -> Int { 0 }
    func fetchSummaries() throws -> [FavoriteGroupSummary] { [] }
    func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? { nil }
    func insert(name: String, members: [String]) throws {}
    func delete(ids: [FavoriteGroupID]) throws {}
}

nonisolated final class SwiftDataGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    override func fetchCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupFavorite>())
    }

    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        let descriptor = FetchDescriptor<GroupFavorite>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.makeSummary() }
    }

    override func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? {
        try fetchModel(id: id)?.makeSnapshot()
    }

    override func insert(name: String, members: [String]) throws {
        context.insert(GroupFavorite(name: name, members: members))
        try context.save()
    }

    override func delete(ids: [FavoriteGroupID]) throws {
        guard !ids.isEmpty else { return }
        // 無料枠は 3 件。SwiftData の #Predicate は外部配列の contains を安定して
        // 扱えないため、全件 1 fetch + Set 判定で対象を集め、まとめて delete する。
        // save は 1 回。ID ごとの fetchModel はしない（N+1 回避）。
        let idSet = Set(ids)
        let favorites = try context.fetch(FetchDescriptor<GroupFavorite>())
        for favorite in favorites where idSet.contains(favorite.id) {
            context.delete(favorite)
        }
        try context.save()
    }

    private func fetchModel(id: FavoriteGroupID) throws -> GroupFavorite? {
        let targetID = id
        let descriptor = FetchDescriptor<GroupFavorite>(
            predicate: #Predicate { $0.id == targetID }
        )
        return try context.fetch(descriptor).first
    }
}

nonisolated final class InMemoryGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private var records: [Record] = []
    /// 同一瞬間の連続 insert でも新しい順が崩れないようにする
    private var nextCreatedAt: TimeInterval = 0

    override func fetchCount() throws -> Int { records.count }

    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        records
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.snapshot.makeSummary() }
    }

    override func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? {
        records.first { $0.snapshot.id == id }?.snapshot
    }

    override func insert(name: String, members: [String]) throws {
        nextCreatedAt += 1
        records.append(
            Record(
                snapshot: FavoriteGroupSnapshot.persisted(name: name, memberNames: members),
                createdAt: Date(timeIntervalSince1970: nextCreatedAt)
            )
        )
    }

    override func delete(ids: [FavoriteGroupID]) throws {
        let idSet = Set(ids)
        records.removeAll { idSet.contains($0.snapshot.id) }
    }

    private struct Record {
        let snapshot: FavoriteGroupSnapshot
        let createdAt: Date
    }
}

extension GroupFavorite {
    fileprivate func makeSnapshot() -> FavoriteGroupSnapshot {
        FavoriteGroupSnapshot.persisted(id: id, name: name, memberNames: members)
    }

    fileprivate func makeSummary() -> FavoriteGroupSummary {
        FavoriteGroupMemberSummary.listing(id: id, name: name, memberNames: members)
    }
}

extension FavoriteGroupSnapshot {
    fileprivate func makeSummary() -> FavoriteGroupSummary {
        FavoriteGroupMemberSummary.listing(id: id, name: name, memberNames: memberNames)
    }
}

/// 字幕結合は Gateway ファイル内だけが担う（Builder は写すだけ）。
private enum FavoriteGroupMemberSummary {
    static func listing(
        id: FavoriteGroupID,
        name: String,
        memberNames: [String]
    ) -> FavoriteGroupSummary {
        FavoriteGroupSummary(
            id: id,
            name: name,
            memberSummary: memberNames.joined(separator: ", ")
        )
    }
}
