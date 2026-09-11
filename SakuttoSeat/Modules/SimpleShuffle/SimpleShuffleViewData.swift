//
//  SimpleShuffleViewData.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（表示専用モデル）
//

import Foundation

/// Presenter が生成し、View が消費する表示専用モデル。
/// View は index を計算しない。
nonisolated struct SimpleShuffleViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let number: Int
        let name: String
    }

    let rows: [Row]

    static let empty = SimpleShuffleViewData(rows: [])
}

nonisolated enum SimpleShuffleViewDataBuilder {
    static func build(seats: [NumberedSeat]) -> SimpleShuffleViewData {
        SimpleShuffleViewData(
            rows: seats.map { seat in
                SimpleShuffleViewData.Row(id: seat.id, number: seat.number, name: seat.name)
            }
        )
    }
}
