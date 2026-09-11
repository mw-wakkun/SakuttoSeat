//
//  GroupFavoriteTestGateways.swift
//  SakuttoSeatTests
//
//  refactor_groupFavorite.md Phase 5（失敗 / カウント用ダブルを 1 系統に集約）
//  本番コードには置かない。FavoriteGroup / AttendeeList の各テストから共有する。
//

import Foundation
@testable import SakuttoSeat

/// insert だけ失敗させる
nonisolated final class FailingInsertGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func insert(name: String, members: [String]) throws {
        throw GroupFavoriteTestError.persistenceFailed(message: "書き込みに失敗しました", code: 1)
    }
}

/// 一覧・詳細の取得を失敗させる（親の `loadFavorite` と子の `allFavorites` の両方）
nonisolated final class FailingFetchGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func fetchCount() throws -> Int {
        throw GroupFavoriteTestError.persistenceFailed(message: "読み込みに失敗しました", code: 2)
    }

    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        throw GroupFavoriteTestError.persistenceFailed(message: "読み込みに失敗しました", code: 2)
    }

    override func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? {
        throw GroupFavoriteTestError.persistenceFailed(message: "読み込みに失敗しました", code: 2)
    }
}

/// 削除だけ失敗させる。一覧は 1 件返す（Presenter の IndexSet 削除経路用）
nonisolated final class FailingDeleteGroupFavoriteGateway: GroupFavoriteGatewayBase {
    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        [FavoriteGroupSummary(id: UUID(), name: "同期", memberSummary: "A")]
    }

    override func delete(ids: [FavoriteGroupID]) throws {
        throw GroupFavoriteTestError.persistenceFailed(message: "削除に失敗しました", code: 1)
    }
}

/// 同一インスタンスが子へ渡されたことを `fetchSummaries` 回数で固定する
nonisolated final class FetchCountingGroupFavoriteGateway: GroupFavoriteGatewayBase {
    private let inner = InMemoryGroupFavoriteGateway()
    private(set) var fetchSummariesCallCount = 0

    override func fetchCount() throws -> Int {
        try inner.fetchCount()
    }

    override func fetchSummaries() throws -> [FavoriteGroupSummary] {
        fetchSummariesCallCount += 1
        return try inner.fetchSummaries()
    }

    override func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot? {
        try inner.fetch(id: id)
    }

    override func insert(name: String, members: [String]) throws {
        try inner.insert(name: name, members: members)
    }

    override func delete(ids: [FavoriteGroupID]) throws {
        try inner.delete(ids: ids)
    }
}

private enum GroupFavoriteTestError {
    static func persistenceFailed(message: String, code: Int) -> NSError {
        NSError(
            domain: "GroupFavoriteTestGateways",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
