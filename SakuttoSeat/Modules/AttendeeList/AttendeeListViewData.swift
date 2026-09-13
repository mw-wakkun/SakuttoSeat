//
//  AttendeeListViewData.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 2 / Phase 5（表示専用モデル）
//

import Foundation

/// Presenter が生成し、View が消費する表示専用モデル。
/// Entity（`Attendee` / `GroupFavorite`）はここに現れない。
/// お気に入り一覧は FavoriteGroup 子モジュールが持つ。
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
    /// ＋ボタンの見た目。判断は Interactor の CapacityDecision を写す。
    let addControl: AttendeeAddControlState
    /// 追加成功のたびに増える。View はこれを見て入力欄を空にする。
    let inputNonce: Int

    static let empty = AttendeeListViewData(
        rows: [],
        isEmpty: true,
        canStartSeating: false,
        canSaveFavorite: false,
        canReset: false,
        addControl: .available,
        inputNonce: 0
    )
}

/// View が＋の色／バッジ／disabled 見た目を切り替えるための状態。
nonisolated enum AttendeeAddControlState: Equatable {
    case available
    case needsUnlock
    case hardLimited
}

nonisolated enum AttendeeListViewDataBuilder {
    static func build(
        attendees: [Attendee],
        addControl: AttendeeAddControlState = .available,
        inputNonce: Int = 0
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
            addControl: addControl,
            inputNonce: inputNonce
        )
    }
}
