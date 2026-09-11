//
//  FavoriteGroupViewData.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 1（Copy。文言自体は変えない）
//  refactor_favorite.md Phase 2（表示専用モデル。Entity はここに現れない）
//  refactor_favorite.md Phase 5（編集トグル文言を Copy に追加。キーは既存 Catalog）
//  refactor_favorite.md Phase 6（閉じる / 編集 / 空状態の A11y。Catalog は ja のみ）
//

import Foundation

// MARK: - Copy

/// 画面・アラート・A11y の文言を 1 系統にまとめる。Catalog は ja のみ（翻訳 locale は増やさない）。
enum FavoriteGroupCopy {
    static var navigationTitle: String { String(localized: "お気に入りグループ") }
    static var emptyMessage: String { String(localized: "登録されているグループはありません") }
    static var emptyAccessibilityHint: String { String(localized: "閉じるボタンで参加者リストに戻ります") }
    static var selectAccessibilityHint: String { String(localized: "このグループを参加者リストに読み込みます") }
    static var editingSelectDisabledHint: String { String(localized: "編集中は読み込みできません") }
    static var edit: String { String(localized: "編集") }
    static var editAccessibilityHint: String { String(localized: "グループを削除できるようにします") }
    static var done: String { String(localized: "完了") }
    static var doneAccessibilityHint: String { String(localized: "編集を終了します") }
    static var close: String { String(localized: "閉じる") }
    static var closeAccessibilityHint: String { String(localized: "保存済みグループの一覧を閉じます") }
    static var ok: String { String(localized: "OK") }
    static var deleteFailedTitle: String { String(localized: "削除に失敗しました") }
    static var loadFailedTitle: String { String(localized: "読み込みに失敗しました") }

    static func rowAccessibilityHint(isEditing: Bool) -> String {
        isEditing ? editingSelectDisabledHint : selectAccessibilityHint
    }

    static func editAccessibilityLabel(isEditing: Bool) -> String {
        isEditing ? done : edit
    }

    static func editButtonAccessibilityHint(isEditing: Bool) -> String {
        isEditing ? doneAccessibilityHint : editAccessibilityHint
    }
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
