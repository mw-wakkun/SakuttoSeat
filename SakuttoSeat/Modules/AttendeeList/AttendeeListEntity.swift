//
//  AttendeeListEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  お気に入りの共有型（ID / Snapshot / Error / Availability）は FavoriteGroupEntity が所有する。
//

import Foundation

/// `nonisolated`: 既定の MainActor 隔離だと `nonisolated` な Interactor から生成できないため。
nonisolated struct Attendee: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
