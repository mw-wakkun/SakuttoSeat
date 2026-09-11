//
//  AttendeeListViewData.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2（表示専用モデル）
//

import Foundation

/// Presenter が生成し、View が消費する表示専用モデル。
/// Entity（`Attendee` / `GroupFavorite`）はここに現れない。
nonisolated struct AttendeeListViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let number: Int
        let name: String
    }

    let rows: [Row]
    let isEmpty: Bool
    let canStartSeating: Bool
    let canSaveFavorite: Bool
    let canReset: Bool
    /// Phase 5 で FavoriteGroup 子モジュールへ移譲するまでの一覧
    let favoriteGroups: [FavoriteGroupSnapshot]

    static let empty = AttendeeListViewData(
        rows: [],
        isEmpty: true,
        canStartSeating: false,
        canSaveFavorite: false,
        canReset: false,
        favoriteGroups: []
    )
}

nonisolated enum AttendeeListViewDataBuilder {
    static func build(
        attendees: [Attendee],
        favoriteGroups: [FavoriteGroupSnapshot] = []
    ) -> AttendeeListViewData {
        let rows = attendees.enumerated().map { index, attendee in
            AttendeeListViewData.Row(
                id: attendee.id,
                number: index + 1,
                name: attendee.name
            )
        }
        let hasAttendees = !attendees.isEmpty
        return AttendeeListViewData(
            rows: rows,
            isEmpty: !hasAttendees,
            canStartSeating: hasAttendees,
            canSaveFavorite: hasAttendees,
            canReset: hasAttendees,
            favoriteGroups: favoriteGroups
        )
    }
}
