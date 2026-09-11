//
//  FavoriteGroupEntity.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 2（共有型の所在。画面 = FavoriteGroup、永続化 = GroupFavorite）
//  refactor_groupFavorite.md Phase 1（@Model の住所は Core/Persistence。型名は変えない）
//  refactor_groupFavorite.md Phase 2（Snapshot は表示結合を持たない）
//  refactor_groupFavorite.md Phase 3（一覧は Summary。memberNames は fetch(id:) だけ）
//

import Foundation

/// お気に入りグループの識別子。永続化モデル `GroupFavorite.id` と同一。
typealias FavoriteGroupID = UUID

/// 読込置換（`fetch(id:)`）専用のスナップショット。表示用結合は持たない。
nonisolated struct FavoriteGroupSnapshot: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]

    /// Gateway が永続化モデルから写すときの工場。
    static func persisted(
        id: FavoriteGroupID = UUID(),
        name: String,
        memberNames: [String]
    ) -> FavoriteGroupSnapshot {
        FavoriteGroupSnapshot(id: id, name: name, memberNames: memberNames)
    }
}

/// 一覧用 DTO。メンバー配列は持たない。字幕は Gateway が載せる（Builder は写すだけ）。
nonisolated struct FavoriteGroupSummary: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberSummary: String
}

/// お気に入り保存の可否。`TemplateSaveAvailability` と同型
nonisolated enum FavoriteSaveAvailability: Equatable {
    case available
    case limitReached(currentCount: Int, limit: Int)
}

/// お気に入り保存・読込・削除の失敗理由
nonisolated enum FavoriteSaveError: Error, Equatable {
    case limitReached(currentCount: Int, limit: Int)
    case invalidName
    case notFound
    case persistenceFailed(message: String)
}
