//
//  GroupFavorite.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/24.
//  永続化モデル（SwiftData）。VIPER 画面モジュールではない。
//  画面名は FavoriteGroup。Snapshot 変換は GroupFavoriteGateway。
//

import Foundation
import SwiftData

@Model
final class GroupFavorite {
    @Attribute(.unique) var id: UUID
    var name: String
    var members: [String]
    var createdAt: Date

    /// `SeatingLayoutTemplate` と同じく `id` / `createdAt` を受け取れる。既存呼び出しはデフォルトで足りる。
    init(
        id: UUID = UUID(),
        name: String,
        members: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.createdAt = createdAt
    }
}
