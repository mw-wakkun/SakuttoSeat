//
//  FavoriteGroupEntity.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 2（共有型の所在。画面 = FavoriteGroup、永続化 = GroupFavorite）
//  refactor_groupFavorite.md Phase 1（@Model の住所は Core/Persistence。型名は変えない）
//

import Foundation

/// お気に入りグループの識別子。永続化モデル `GroupFavorite.id` と同一。
typealias FavoriteGroupID = UUID

/// SwiftData モデル（`GroupFavorite`）を View / Presenter から隔離するスナップショット。
/// 一覧の表示用結合（`memberSummary`）は ViewData Builder が担う。
nonisolated struct FavoriteGroupSnapshot: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]
    let memberSummary: String

    /// Gateway が永続化モデルから写すときの工場。表示用結合は Builder が再計算する。
    static func persisted(
        id: FavoriteGroupID = UUID(),
        name: String,
        memberNames: [String]
    ) -> FavoriteGroupSnapshot {
        FavoriteGroupSnapshot(
            id: id,
            name: name,
            memberNames: memberNames,
            memberSummary: memberNames.joined(separator: ", ")
        )
    }
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
