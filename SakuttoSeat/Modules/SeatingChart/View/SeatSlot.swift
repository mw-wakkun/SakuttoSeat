//
//  SeatSlot.swift
//  SakuttoSeat
//

import Foundation

/// 座席1つ分の表示単位（空席を含む）
///
/// `id` は在席なら参加者 ID、空席ならテーブル ID と位置から作る。
/// シャッフルでは参加者の並び順だけが変わり id 自体は変わらないため、
/// SwiftUI が同じ座席の「移動」として認識でき、滑らかにアニメーションできる。
///
/// Phase 2 でこの組み立てを Presenter（ViewData）側へ移送する。
struct SeatSlot: Identifiable, Equatable {
    let id: String
    let member: SeatingMember?

    var isOccupied: Bool { member != nil }
}

extension SeatSlot {
    /// テーブルの在席と空席を、1次元の座席の並びへ展開する
    ///
    /// 在席を `assignedMembers` の順に並べ、定員に足りない分を空席で埋める。
    static func slots(for table: SeatingTable) -> [SeatSlot] {
        let tableIDString = table.id.uuidString
        var slots = table.assignedMembers.map { member in
            SeatSlot(id: member.id.uuidString, member: member)
        }

        let emptyCount = max(0, table.capacity - table.assignedMembers.count)
        for index in 0..<emptyCount {
            slots.append(SeatSlot(id: "\(tableIDString)-empty-\(index)", member: nil))
        }

        return slots
    }
}
