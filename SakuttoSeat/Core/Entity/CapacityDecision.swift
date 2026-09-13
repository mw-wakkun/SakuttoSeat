//
//  CapacityDecision.swift
//  SakuttoSeat
//
//  v2.1（人数・卓・列の追加可否。UnlockRequirement は2値のまま残す）
//

import Foundation

/// 絶対上限に当たった理由。広告 CTA は出さない。
nonisolated enum HardLimitReason: Equatable {
    case attendee
    case table
    case totalSeat
}

/// 追加・適用の直前判定。Interactor だけが返す。
///
/// `UnlockRequirement` に `.blocked` を足さない（Share の契約を壊さない）。
nonisolated enum CapacityDecision: Equatable {
    case allowed
    case requiresUnlock
    case blockedHardLimit(HardLimitReason)
}
