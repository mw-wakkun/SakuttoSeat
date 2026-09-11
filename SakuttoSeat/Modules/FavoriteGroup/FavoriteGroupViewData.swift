//
//  FavoriteGroupViewData.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 2（表示専用モデル。Entity はここに現れない）
//

import Foundation

/// Presenter が生成し、View が消費する表示専用モデル。
/// Entity（`FavoriteGroupSnapshot` / `GroupFavorite`）はここに現れない。
nonisolated struct FavoriteGroupViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: FavoriteGroupID
        let name: String
        let memberSummary: String
    }

    let rows: [Row]
    var isEmpty: Bool { rows.isEmpty }

    static let empty = FavoriteGroupViewData(rows: [])
}

nonisolated enum FavoriteGroupViewDataBuilder {
    static func build(groups: [FavoriteGroupSnapshot]) -> FavoriteGroupViewData {
        FavoriteGroupViewData(
            rows: groups.map { group in
                FavoriteGroupViewData.Row(
                    id: group.id,
                    name: group.name,
                    memberSummary: group.memberNames.joined(separator: ", ")
                )
            }
        )
    }
}
