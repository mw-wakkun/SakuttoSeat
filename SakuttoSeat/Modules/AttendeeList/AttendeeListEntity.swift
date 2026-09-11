//
//  AttendeeListEntity.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
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

typealias FavoriteGroupID = UUID

/// SwiftData モデル（`GroupFavorite`）を View / Presenter から隔離するスナップショット
nonisolated struct FavoriteGroupSnapshot: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]
    let memberSummary: String
}

/// お気に入り保存の可否。`TemplateSaveAvailability` と同型（Phase 3 で Interactor に移す）
nonisolated enum FavoriteSaveAvailability: Equatable {
    case available
    case limitReached(currentCount: Int, limit: Int)
}
