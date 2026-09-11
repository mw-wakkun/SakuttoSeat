//
//  FavoriteGroupViewData.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 1（Copy。文言自体は変えない）
//  refactor_favorite.md Phase 2（表示専用モデル。Entity はここに現れない）
//

import Foundation

// MARK: - Copy

/// 画面・アラート・A11y の文言を 1 系統にまとめる。Catalog キーは既存のまま。
enum FavoriteGroupCopy {
    static var navigationTitle: String { String(localized: "お気に入りグループ") }
    static var emptyMessage: String { String(localized: "登録されているグループはありません") }
    static var selectAccessibilityHint: String { String(localized: "このグループを参加者リストに読み込みます") }
    static var close: String { String(localized: "閉じる") }
    static var ok: String { String(localized: "OK") }
    static var deleteFailedTitle: String { String(localized: "削除に失敗しました") }
    static var loadFailedTitle: String { String(localized: "読み込みに失敗しました") }
}

// MARK: - ViewData

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
