//
//  SimpleShuffleViewData.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（表示専用モデル）
//  refactor_simple.md Phase 3（canShuffle / Copy。title は View 側 Catalog）
//  refactor_simple.md Phase 4（空状態 Copy）
//

import Foundation

// MARK: - Copy

/// 画面・Snapshot・A11y の文言を 1 系統にまとめる。
/// `snapshotTitle` と `listHeader` は意図的に別（共有先での文脈用。§8.8）。
enum SimpleShuffleCopy {
    static var navigationTitle: String { String(localized: "番号札") }
    static var listHeader: String { String(localized: "シャッフル結果") }
    static var listFooter: String { String(localized: "この番号の席に座ってもらいましょう。") }
    static var snapshotBrand: String { String(localized: "【サクッと席決め】") }
    static var snapshotTitle: String { String(localized: "シャッフル結果（番号札）") }
    static var accessory: String { String(localized: "番席") }
    static var shareAccessibilityLabel: String { String(localized: "共有") }
    static var shareAccessibilityHint: String { String(localized: "結果を共有します") }
    static var shuffleAccessibilityLabel: String { String(localized: "シャッフル") }
    static var shuffleAccessibilityHint: String { String(localized: "席順をシャッフルします") }
    static var shuffleDisabledHint: String { String(localized: "2名以上で席順をシャッフルできます") }
    static var shuffleAnnouncement: String { String(localized: "席順を更新しました") }
    static var emptyMessage: String { String(localized: "参加者がいません") }
}

// MARK: - ViewData

/// Presenter が生成し、View が消費する表示専用モデル。
/// View は index を計算しない。文言は `SimpleShuffleCopy`。
nonisolated struct SimpleShuffleViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let number: Int
        let name: String
    }

    let rows: [Row]
    let isEmpty: Bool
    /// 2 名以上。View は disable するだけ
    let canShuffle: Bool

    static let empty = SimpleShuffleViewData(rows: [], isEmpty: true, canShuffle: false)
}

nonisolated enum SimpleShuffleViewDataBuilder {
    static func build(seats: [NumberedSeat]) -> SimpleShuffleViewData {
        SimpleShuffleViewData(
            rows: seats.map { seat in
                SimpleShuffleViewData.Row(id: seat.id, number: seat.number, name: seat.name)
            },
            isEmpty: seats.isEmpty,
            canShuffle: seats.count >= 2
        )
    }
}
