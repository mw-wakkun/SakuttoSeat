//
//  AttendeeListEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  お気に入りの共有型（ID / Snapshot / Error / Availability）は FavoriteGroupEntity が所有する。
//

import Foundation

/// 人数上限を踏まえた追加結果。溢れた名前は Presenter がバッファする。
nonisolated struct AttendeeAppendResult: Equatable {
    let attendees: [Attendee]
    let overflowNames: [String]
    let decision: CapacityDecision
    /// 今回追加しようとした人数（空行を除く）
    let triedCount: Int
    /// 追加直前の無料残り枠。ダイアログ文言の出し分けに使う。
    let remainingFreeAtStart: Int
    /// 追加直前の絶対上限までの残り枠。
    let remainingHardAtStart: Int
}

/// `nonisolated`: 既定の MainActor 隔離だと `nonisolated` な Interactor から生成できないため。
nonisolated struct Attendee: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
