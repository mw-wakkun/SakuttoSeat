//
//  SimpleShuffleEntity.swift
//  SakuttoSeat
//
//  refactor_simple.md Phase 1（name は不変。number だけシャッフル後に付け替える）
//

import Foundation

/// 番号札 1 行。親から渡された `Attendee.id` を維持する。
///
/// `nonisolated`: 既定の MainActor 隔離だと `nonisolated` な Interactor から生成できないため。
nonisolated struct NumberedSeat: Identifiable, Equatable {
    let id: UUID
    let name: String
    var number: Int
}
